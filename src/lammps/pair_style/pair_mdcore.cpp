/* ======================================================================
   MDCORE - Interatomic potential library
   https://github.com/pastewka/mdcore
   Lars Pastewka, lars.pastewka@iwm.fraunhofer.de, and others
   See the AUTHORS file in the top-level MDCORE directory.

   Copyright (2005-2013) Fraunhofer IWM
   This software is distributed under the GNU General Public License.
   See the LICENSE file in the top-level MDCORE directory.
   ====================================================================== */

/* ----------------------------------------------------------------------
   LAMMPS - Large-scale Atomic/Molecular Massively Parallel Simulator
   http://lammps.sandia.gov, Sandia National Laboratories
   Steve Plimpton, sjplimp@sandia.gov

   Copyright (2003) Sandia Corporation.  Under the terms of Contract
   DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
   certain rights in this software.  This software is distributed under 
   the GNU General Public License.

   See the README file in the top-level LAMMPS directory.
------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------
   Contributing author: Tim Kunze (FZDR), Lars Pastewka (Fh-IWM, JHU)
------------------------------------------------------------------------- */

#include "math.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "mpi.h"
#include "pair_mdcore.h"
#include "atom.h"
#include "force.h"
#include "comm.h"
#include "neighbor.h"
#include "neigh_list.h"
#include "neigh_request.h"
#include "memory.h"
#include "error.h"
#include<iostream>
//#include<vector>
#include "update.h"

#include "potentials_factory_c.h"

using namespace LAMMPS_NS;

#define ERROR_NONE 0
#define ERRSTRLEN 10000

/* ---------------------------------------------------------------------- */

int error2lmp(Error *error, const char *fn, int line, int ierror)
{
  char errstr[ERRSTRLEN];

  if (ierror != ERROR_NONE) {
    get_full_error_string(errstr);
    error->all(fn,line,errstr);
    return 1;
  } else {
    return 0;
  }   
}

/* ---------------------------------------------------------------------- */

PairMDCORE::PairMDCORE(LAMMPS *lmp) : Pair(lmp)
{
  single_enable = 0;
  one_coeff = 1;
  no_virial_fdotr_compute = 1;
  ghostneigh = 1;

  name_ = NULL;
  fn_ = NULL;

  maxlocal_ = 0;
  MDCORE_seed_ = NULL;
  MDCORE_last_ = NULL;
  MDCORE_nneighb_ = 0;
  MDCORE_neighb_ = NULL;

  particles_new(&particles_);
  particles_init(particles_);

  neighbors_new(&neighbors_);
  neighbors_init(neighbors_);

  class_ = NULL;
  members_ = NULL;
  potential_ = NULL;

  mdcore_startup(-1);
}

/* ----------------------------------------------------------------------
   check if allocated, since class can be destructed when incomplete
------------------------------------------------------------------------- */

PairMDCORE::~PairMDCORE()
{
  if (name_)  free(name_);

  if (potential_) {
    class_->del(potential_);
    class_->free_instance(potential_);
  }

  memory->sfree(MDCORE_seed_);
  memory->sfree(MDCORE_last_);

  if (allocated) {
    memory->destroy(setflag);
    memory->destroy(rcmaxsq_);
    memory->destroy(cutsq);
    memory->destroy(cutghost);
  }

  if (neighbors_) {
    neighbors_del(neighbors_);
    neighbors_free(neighbors_);
  }

  if (particles_) {
    particles_del(particles_);
    particles_free(particles_);
  }

  mdcore_shutdown();
}

/* ---------------------------------------------------------------------- */

void PairMDCORE::compute(int eflag, int vflag)
{
  if (eflag || vflag) ev_setup(eflag,vflag);
  else evflag = vflag_fdotr = vflag_atom = 0;

  MDCORE_neigh();
  FMDCORE(eflag,vflag);
}

/* ----------------------------------------------------------------------
   allocate all arrays
------------------------------------------------------------------------- */

void PairMDCORE::allocate()
{
  allocated = 1;
  int n = atom->ntypes;

  memory->create(setflag,n+1,n+1,"pair:setflag");
  for (int i = 1; i <= n; i++)
    for (int j = i; j <= n; j++)
      setflag[i][j] = 0;

  memory->create(rcmaxsq_,n+1,n+1,"pair:rcmaxsq");
  memory->create(cutsq,n+1,n+1,"pair:cutsq");
  memory->create(cutghost,n+1,n+1,"pair:cutghost");
}

/* ----------------------------------------------------------------------
   global settings
------------------------------------------------------------------------- */

void PairMDCORE::settings(int narg, char **arg)
{
  if (narg != 1 && narg != 2)
    error->all(FLERR,"pair_style mdcore expects potential name and "
	       "configuration file as parameters");

  name_ = strdup(arg[0]);
  if (narg == 2)
    fn_ = strdup(arg[1]);
}

/* ----------------------------------------------------------------------
   set coeffs for one or more type pairs
------------------------------------------------------------------------- */

void PairMDCORE::coeff(int narg, char **arg)
{
  int n = atom->ntypes;
  int map[n];

  if (!allocated)  allocate();

  if (narg != 2 + n) {
    char errstr[1024];
    sprintf(errstr,"Incorrect number of arguments for pair coefficients. "
	    "There are %i atom types in this system.", n);
    error->all(FLERR,errstr);
  }

  // ensure I,J args are * *

  if (strcmp(arg[0],"*") != 0 || strcmp(arg[1],"*") != 0)
    error->all(FLERR,"Incorrect args for pair coefficients; must be * *");

  // read args that map atom types to C and H
  // map[i] = which element (0,1) the Ith atom type is, -1 if NULL

  for (int i = 2; i < narg; i++) {
    map[i-1] = 0;
    if (strcmp(arg[i],"NULL") == 0) {
      map[i-1] = -1;
      continue;
    } else {
      int Z, ierror;
      particles_set_element(particles_,arg[i],n,i-1,&Z,&ierror);
      error2lmp(error,FLERR,ierror);
      map[i-1] = Z;
    }
  }

  // clear setflag since coeff() called once with I,J = * *

  for (int i = 1; i <= n; i++)
    for (int j = i; j <= n; j++)
      setflag[i][j] = 0;

  // set setflag i,j for type pairs where both are mapped to elements

  int count = 0;
  for (int i = 1; i <= n; i++)
    for (int j = i; j <= n; j++)
      if (map[i] >= 0 && map[j] >= 0) {
	setflag[i][j] = 1;
	count++;
      }

  if (count == 0) error->all(FLERR,"Incorrect args for pair coefficients -> "
			     "count = 0");
}

/* ----------------------------------------------------------------------
   init specific to this pair style
------------------------------------------------------------------------- */

void PairMDCORE::init_style()
{
  if (!allocated)
    error->all(FLERR,"Something wrong. pair mdcore not allocated.");

  if (strcmp(update->unit_style,"metal"))
    error->all(FLERR,"Pair style mdcore requires metal units");
  if (atom->tag_enable == 0)
    error->all(FLERR,"Pair style mdcore requires atom IDs");
  if (force->newton_pair == 0)
    error->all(FLERR,"Pair style mdcore requires newton pair on");

  // need a full neighbor list

  int irequest = neighbor->request(this);
  neighbor->requests[irequest]->half = 0;
  neighbor->requests[irequest]->full = 1;
  neighbor->requests[irequest]->ghost = 1;

  // find potential class in MDCORE potential database

  class_ = NULL;
  for (int i = 0; i < N_CLASSES; i++) {
    if (!strcmp(name_,potential_classes[i].name))
      class_ = &potential_classes[i];
  }
  if (!class_) {
    char errstr[1024];
    sprintf(errstr,"Could not find potential '%s' in the MDCORE potential "
	    "database",name_);
    error->all(FLERR,errstr);
  }

  // initialize  potential object

  section_t *zero = NULL;
  class_->new_instance(&potential_,zero,&members_);

  if (fn_) {
    ptrdict_read(members_, fn_);
  }

  // set pointers in particles object
  particles_set_pointers(particles_,atom->nlocal+atom->nghost,atom->nlocal,
			 atom->nmax,atom->tag,atom->type,&atom->x[0][0]);

  class_->init(potential_);

  int ierror;
  class_->bind_to(potential_,particles_,neighbors_,&ierror);
  error2lmp(error,FLERR,ierror);

  // dump all cutoffs to the MDCORE log file

  neighbors_dump_cutoffs(neighbors_,particles_);

  // determine width of ghost communication border

  double rc;
  particles_get_border(particles_,&rc);
  comm->cutghostuser = MAX(comm->cutghostuser,rc);
}

/* ----------------------------------------------------------------------
   init for one type pair i,j and corresponding j,i
------------------------------------------------------------------------- */

double PairMDCORE::init_one(int i, int j)
{
  if (setflag[i][j] == 0) error->all(FLERR,"All pair coeffs are not set");

  double rc;

  neighbors_get_cutoff(neighbors_,i,j,&rc);

  rcmaxsq_[i][j] = rcmaxsq_[j][i] = rc*rc;
  cutghost[i][j] = cutghost[j][i] = rc;

  return rc;
}

/* ----------------------------------------------------------------------
   create MDCORE neighbor list from main neighbor list
   MDCORE neighbor list stores neighbors of ghost atoms
------------------------------------------------------------------------- */

void PairMDCORE::MDCORE_neigh()
{
  //printf("...entering MDCORE_neigh():\n");
  int i,j,ii,jj,n,inum,jnum,itype,jtype;
  double xtmp,ytmp,ztmp,delx,dely,delz,rsq;
  int *ilist,*jlist,*numneigh,**firstneigh;

  double **x = atom->x;
  int *type = atom->type;
  int nlocal = atom->nlocal;
  int nall = nlocal + atom->nghost;

  if (!list->ghostflag) {
    error->all(FLERR,"MDCORE needs neighbor list with ghost atoms.");
  }

  if (nall > maxlocal_) {
    maxlocal_ = atom->nmax;
    memory->sfree(MDCORE_seed_);
    memory->sfree(MDCORE_last_);
    MDCORE_seed_ = (int *)
      memory->smalloc(maxlocal_*sizeof(int),"MDCORE:MDCORE_seed");
    MDCORE_last_ = (int *)
      memory->smalloc(maxlocal_*sizeof(int),"MDCORE:MDCORE_last");
  }

  // set start values for neighbor array MDCORE_neighb
  for (i = 0; i < nall; i++) {
    MDCORE_seed_[i] = -1;
    MDCORE_last_[i] = -2;
  }

  inum = list->inum+list->gnum;
  ilist = list->ilist;
  numneigh = list->numneigh;
  firstneigh = list->firstneigh;

  // Map seed and last arrays to point to the appropriate position in the native
  // LAMMPS neighbor list
  MDCORE_neighb_ = &firstneigh[0][0];
  MDCORE_nneighb_ = 0;
  for (ii = 0; ii < inum; ii++) {
    i = ilist[ii];
    // MDCORE seed index is index relative to beginning of the neighbor array
    MDCORE_seed_[i] = (int) (firstneigh[i]-MDCORE_neighb_)+1;
    MDCORE_last_[i] = MDCORE_seed_[i]+numneigh[i]-1;
    MDCORE_nneighb_ = MAX(MDCORE_nneighb_, MDCORE_last_[i]);
  }

#if 0
  // DEBUG: Check if neighbor list is symmetric
  for (i = 0; i < nall; i++) {
    xtmp = x[i][0];
    ytmp = x[i][1];
    ztmp = x[i][2];
    for (ii = MDCORE_seed_[i]-1; ii < MDCORE_last_[i]; ii++) {
      j = MDCORE_neighb_[ii]-1;

      // Check if i is neighbor of j
      n = 0;
      for (jj = MDCORE_seed_[j]-1; jj < MDCORE_last_[j]; jj++) {
	if (MDCORE_neighb_[jj]-1 == i) {
	  n = 1;
	}
      }
      if (!n) {
	printf("i = %i, j = %i\n", i, j);
	printf("Neighbors of i\n");
	for (jj = MDCORE_seed_[i]-1; jj < MDCORE_last_[i]; jj++) {
	  j = MDCORE_neighb_[jj]-1;
	  delx = xtmp - x[j][0];
	  dely = ytmp - x[j][1];
	  delz = ztmp - x[j][2];
	  printf("   %i  %f\n", j, sqrt(delx*delx+dely*dely+delz*delz));
	}
	printf("Neighbors of j\n");
	for (jj = MDCORE_seed_[j]-1; jj < MDCORE_last_[j]; jj++) {
	  j = MDCORE_neighb_[jj]-1;
	  delx = xtmp - x[j][0];
	  dely = ytmp - x[j][1];
	  delz = ztmp - x[j][2];
	  printf("   %i  %f\n", j, sqrt(delx*delx+dely*dely+delz*delz));
	}
	error->one(FLERR,"Neighbor list not symmetric");
      }
    }
  }
#endif
}

/* ----------------------------------------------------------------------
   MDCORE forces and energy
------------------------------------------------------------------------- */

void PairMDCORE::FMDCORE(int eflag, int vflag)
{
  double **x = atom->x;
  double **f = atom->f;
  int *tag = atom->tag;
  int *type = atom->type;
  int nlocal = atom->nlocal;
  int nall = nlocal + atom->nghost;
  double epot,*epot_per_at,*wpot_per_at,wpot[3][3];

  memset(wpot, 0, 9*sizeof(double));

  epot_per_at = NULL;
  if (eflag_atom) {
    epot_per_at = &eatom[0];
  }

  wpot_per_at = NULL;
  if (vflag_atom) {
    wpot_per_at = &vatom[0][0];
  }

  // set pointers in particles object
  particles_set_pointers(particles_,nall,atom->nlocal,atom->nmax,tag,
			 type,&x[0][0]);

  // set pointers in neighbor list object
  neighbors_set_pointers(neighbors_,nall,MDCORE_seed_,MDCORE_last_,
			 MDCORE_nneighb_,MDCORE_neighb_);

  int ierror;
  epot = 0.0;
  class_->energy_and_forces(potential_,particles_,neighbors_,&epot,
			    &f[0][0],&wpot[0][0],epot_per_at,NULL,NULL,
			    wpot_per_at,NULL,&ierror);
  error2lmp(error,FLERR,ierror);

  if (evflag) {
    // update energies
    eng_vdwl += epot;

    // update virial
    virial[0] -= wpot[0][0];
    virial[1] -= wpot[1][1];
    virial[2] -= wpot[2][2];
    virial[3] -= 0.5*(wpot[1][0]+wpot[0][1]);
    virial[4] -= 0.5*(wpot[2][0]+wpot[0][2]);
    virial[5] -= 0.5*(wpot[2][1]+wpot[1][2]);
  }
}

/* ----------------------------------------------------------------------
   memory usage of local atom-based arrays 
------------------------------------------------------------------------- */

double PairMDCORE::memory_usage()
{
  double bytes = 0.0;
  return bytes;
}

