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

#ifdef PAIR_CLASS

PairStyle(mdcore,PairMDCORE)

#else

#ifndef LMP_PAIR_MDCORE_H
#define LMP_PAIR_MDCORE_H

#include "pair.h"

#include "ptrdict.h"
#include "potentials_factory_c.h"

namespace LAMMPS_NS {

class PairMDCORE : public Pair {
 public:
  PairMDCORE(class LAMMPS *);
  ~PairMDCORE();
  void compute(int, int);
  void settings(int, char **);
  void coeff(int, char **);
  void init_style();
  double init_one(int, int);
  double memory_usage();

 private:
  char *name_;                     // name of the potential
  char *fn_;                       // file name with potential parameters
  int maxlocal_;                   // size of numneigh, firstneigh arrays

  int *MDCORE_seed_;
  int *MDCORE_last_;
  int *MDCORE_neighb_;
  int MDCORE_nneighb_;

  double **rcmaxsq_;

  // pointer to the -member descriptor
  section_t *members_;

  // pointer to the -class descriptor
  potential_class_t *class_;

  // particles, neighbors and potential objects
  void *particles_,*neighbors_,*potential_;

  void MDCORE_neigh();
  void FMDCORE(int, int);

  void allocate();
};

}

extern "C" {

  void particles_new(void **self);            // allocate particles object
  void particles_free(void *self);            // free particles object
  
  void particles_init(void *self);            // initialize particles object
  void particles_del(void *self);             // finalize particles object

  void particles_set_element(void *self, char *el_str, int nel, int el_no, 
			     int *Z, int *error);
  void particles_set_pointers(void *self, int nat, int natloc, int maxnatloc,
			      void *tag, void *el, void *r);

  void particles_get_border(void *self, double *border);


  void neighbors_new(void **self);            // allocate neighbors object
  void neighbors_free(void *self);            // free neighbors object
  
  void neighbors_init(void *self);            // initialize neighbors object
  void neighbors_del(void *self);             // finalize neighbors object

  void neighbors_set_pointers(void *self, int natloc, void *seed, void *last,
			      int neighbors_size, void *neighbors);

  void neighbors_get_cutoff(void *self, int Z1, int Z2, double *cutoff);
  void neighbors_dump_cutoffs(void *self, void *p);

  void mdcore_startup(int);
  void mdcore_shutdown(void);
  void timer_print_to_log(void);
  void get_full_error_string(char *);

}

#endif
#endif
