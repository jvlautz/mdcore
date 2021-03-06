!! ======================================================================
!! MDCORE - Interatomic potential library
!! https://github.com/pastewka/mdcore
!! Lars Pastewka, lars.pastewka@iwm.fraunhofer.de, and others
!! See the AUTHORS file in the top-level MDCORE directory.
!!
!! Copyright (2005-2013) Fraunhofer IWM
!! This software is distributed under the GNU General Public License.
!! See the LICENSE file in the top-level MDCORE directory.
!! ======================================================================

  !>
  !! The BOP class
  !<
  public :: BOP_TYPE
  type BOP_TYPE

     type(BOP_DB_TYPE)  :: db = Tersoff_PRB_39_5566_SiC   !< Parameterization

     integer  :: Z2db(MAX_Z)

     !
     ! Counters
     !

     logical  :: neighbor_list_allocated  = .false.
     integer  :: it                       = 0

     !
     ! Cut-off information required by BOP_KERNEL
     !

     real(DP)  :: cut_in_l(TERSOFF_MAX_PAIRS)     !< Inner cutoff
     real(DP)  :: cut_in_h(TERSOFF_MAX_PAIRS)     !< Outer cutoff
     real(DP)  :: cut_in_h2(TERSOFF_MAX_PAIRS)    !< Outer cutoff squared

     !
     ! Internal neighbor lists
     !

     integer                :: nebmax = 20
     integer                :: nebavg = 20

     integer, allocatable   :: neb(:)
     integer, allocatable   :: nbb(:)
#ifndef LAMMPS
     integer, allocatable   :: dcell(:)
#endif

     integer, allocatable   :: bndtyp(:)
     real(DP), allocatable  :: bndlen(:)
     real(DP), allocatable  :: bndnm(:, :)
     real(DP), allocatable  :: cutfcnar(:), cutdrvar(:)

#ifdef SCREENING

! The other cutoffs are identical!
#define cut_ar_h  cut_out_h

     real(DP)  :: cut_out_h(TERSOFF_MAX_PAIRS)
     real(DP)  :: cut_out_l(TERSOFF_MAX_PAIRS)

     real(DP)  :: cut_bo_h(TERSOFF_MAX_PAIRS)
     real(DP)  :: cut_bo_l(TERSOFF_MAX_PAIRS)

     real(DP)  :: max_cut_sq(TERSOFF_MAX_PAIRS)

     real(DP)  :: Cmin(TERSOFF_MAX_PAIRS)
     real(DP)  :: Cmax(TERSOFF_MAX_PAIRS)
     real(DP)  :: dC(TERSOFF_MAX_PAIRS)
     real(DP)  :: C_dr_cut(TERSOFF_MAX_PAIRS)

     real(DP)  :: screening_threshold  = log(1d-6)
     real(DP)  :: dot_threshold        = 1e-10

     real(DP), allocatable  :: cutfcnbo(:), cutdrvbo(:)
     ! "screened" neighbor list (all neighbors of a bond which sit in the
     ! screening cutoff)
     integer, allocatable   :: sneb_seed(:)
     integer, allocatable   :: sneb_last(:)
     integer, allocatable   :: sneb(:)
     integer, allocatable   :: sbnd(:)

     ! for force calculation
     real(DP), allocatable  :: sfacbo(:)

     real(DP), allocatable  :: cutdrarik(:), cutdrarjk(:)
     real(DP), allocatable  :: cutdrboik(:), cutdrbojk(:)
#endif

  endtype BOP_TYPE


  public :: init
  interface init
     module procedure INIT_FUNC
  endinterface

  public :: del
  interface del
     module procedure DEL_FUNC
  endinterface

  public :: bind_to
  interface bind_to
     module procedure BIND_TO_FUNC
  endinterface

  public :: energy_and_forces
  interface energy_and_forces
     module procedure COMPUTE_FUNC
  endinterface

  public :: register
  interface register
     module procedure REGISTER_FUNC
  endinterface register
