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

#include "macros.inc"

module neighbors_wrap
  use supplib

  use particles
  use neighbors

  implicit none

contains

  !>
  !! Allocate neighbor list
  !<
  subroutine f_neighbors_new(this_cptr) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr), intent(out)  :: this_cptr

    ! ---

    type(neighbors_t), pointer  :: this

    allocate(this)
    this_cptr = c_loc(this)

  endsubroutine f_neighbors_new


  !>
  !! Deallocate neighbor list
  !<
  subroutine f_neighbors_free(this_cptr) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr), value  :: this_cptr

    ! ---

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    call del(this)
    deallocate(this)

  endsubroutine f_neighbors_free


  subroutine f_neighbors_init(this_cptr, avgn) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),     value  :: this_cptr
    integer(c_int),  value  :: avgn
    

    ! ---

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    call init(this, avgn)

  endsubroutine f_neighbors_init


  subroutine f_neighbors_del(this_cptr) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr), value  :: this_cptr

    ! ---

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    call del(this)

  endsubroutine f_neighbors_del


  subroutine f_neighbors_set(this_cptr, avgn, cutoff, verlet_shell, bin_size) &
       bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),     value  :: this_cptr
    integer(c_int),  value  :: avgn
    real(c_double),  value  :: cutoff
    real(c_double),  value  :: verlet_shell
    real(c_double),  value  :: bin_size
    

    ! ---

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    call set(this, avgn, cutoff, verlet_shell, bin_size)

  endsubroutine f_neighbors_set


  subroutine f_neighbors_request_interaction_range(this_cptr, cutoff) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value   :: this_cptr
    real(c_double), value   :: cutoff

    ! ---

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    call request_interaction_range(this, cutoff)

  endsubroutine f_neighbors_request_interaction_range


  subroutine f_neighbors_update(this_cptr, p_cptr, ierror) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),     value        :: this_cptr
    type(c_ptr),     value        :: p_cptr
    integer(c_int),  intent(out)  :: ierror

    ! ---

    type(neighbors_t), pointer  :: this
    type(particles_t), pointer  :: p

    ! ---

    call c_f_pointer(this_cptr, this)
    call c_f_pointer(p_cptr, p)
    call update(this, p, ierror)

  endsubroutine f_neighbors_update


  subroutine f_neighbors_find_neighbor(this_cptr, i, j, n1, n2) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),     value        :: this_cptr
    integer(c_int),  value        :: i
    integer(c_int),  value        :: j
    integer(c_int),  intent(out)  :: n1
    integer(c_int),  intent(out)  :: n2

    ! ---

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    call find_neighbor(this, i, j, n1, n2)

  endsubroutine f_neighbors_find_neighbor


  !>
  !! Return total size of neighbor list
  !<
  function f_get_neighbors_size(this_cptr) bind(C) result(s)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value        :: this_cptr
    integer(c_int)               :: s

    type(neighbors_t), pointer  :: this

    ! ---

    call c_f_pointer(this_cptr, this)
    s  = this%neighbors_size

  endfunction f_get_neighbors_size


  !>
  !! Compute coordination number
  !<
  function f_get_coordination(this_cptr, i, cutoff) bind(C) result(c)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value        :: this_cptr
    integer(c_int), value        :: i
    real(c_double), value        :: cutoff
    integer(c_int)               :: c

    ! ---

    type(neighbors_t), pointer  :: this

    integer   :: ni
    real(DP)  :: dr(3), abs_dr_sq, cutoff_sq

    ! ---

    call c_f_pointer(this_cptr, this)

    cutoff_sq  = cutoff**2

    c  = 0

    do ni = this%seed(i), this%last(i)
       DIST_SQ(this%p, this, i, ni, dr, abs_dr_sq)

       if (abs_dr_sq < cutoff_sq) then
          c  = c + 1
       endif
    enddo

  endfunction f_get_coordination


  !>
  !! Compute coordination numbers for all atoms
  !<
  subroutine f_get_coordination_numbers(this_cptr, cutoff, c) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value        :: this_cptr
    real(c_double), value        :: cutoff
    integer(c_int)               :: c(*)

    ! ---

    type(neighbors_t), pointer  :: this

    integer   :: i, ni
    real(DP)  :: dr(3), abs_dr_sq, cutoff_sq

    ! ---

    call c_f_pointer(this_cptr, this)

    cutoff_sq  = cutoff**2

    c(1:this%p%nat) = 0
    do i = 1, this%p%nat
       do ni = this%seed(i), this%last(i)
          if (GET_ABS_DR_SQ(this%p, this, i, ni) < cutoff_sq) then
             c(i) = c(i) + 1
          endif
       enddo
    enddo

  endsubroutine f_get_coordination_numbers


  !>
  !! Return total number of neighbors
  !<
  function f_get_number_of_neighbors(this_cptr, i1) bind(C) result(s)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    integer(c_int), value  :: i1
    integer(c_int)         :: s

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i

    ! ---

    call c_f_pointer(this_cptr, this)

    i = i1+1
    s = this%last(i)-this%seed(i)+1

  endfunction f_get_number_of_neighbors


  !>
  !! Return total number of neighbors
  !<
  function f_get_number_of_all_neighbors(this_cptr) bind(C) result(s)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    integer(c_int)         :: s

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i

    ! ---

    call c_f_pointer(this_cptr, this)

    s = 0
    do i = 1, this%p%nat
       s = s + this%last(i)-this%seed(i)+1
    enddo

  endfunction f_get_number_of_all_neighbors


  !>
  !! Return neighbors and distances
  !<
  subroutine f_get_neighbors(this_cptr, i1, i2, r) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    integer(c_int), value  :: i1
    integer(c_int)         :: i2(*)
    real(c_double)         :: r(*)

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i, ni, j

    ! ---

    call c_f_pointer(this_cptr, this)

    i = i1+1
    j = 0
    do ni = this%seed(i), this%last(i)
       j = j + 1
       i2(j) = this%neighbors(ni)-1
       r(j)  = GET_ABS_DR(this%p, this, i, ni)
    enddo

  endsubroutine f_get_neighbors


  !>
  !! Return neighbors and distances
  !<
  subroutine f_get_all_neighbors(this_cptr, i1, i2, r) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    integer(c_int)         :: i1(*)
    integer(c_int)         :: i2(*)
    real(c_double)         :: r(*)

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i, ni, j

    ! ---

    call c_f_pointer(this_cptr, this)

    j = 0
    do i = 1, this%p%nat
       do ni = this%seed(i), this%last(i)
          j = j + 1
          i1(j) = i-1
          i2(j) = this%neighbors(ni)-1
          r(j)  = GET_ABS_DR(this%p, this, i, ni)
       enddo
    enddo

  endsubroutine f_get_all_neighbors


  !>
  !! Return neighbors and distances
  !<
  subroutine f_get_all_neighbors_vec(this_cptr, i1, i2, dr, abs_dr) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    integer(c_int)         :: i1(*)
    integer(c_int)         :: i2(*)
    real(c_double)         :: dr(3, *)
    real(c_double)         :: abs_dr(*)

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i, ni, j

    ! ---

    call c_f_pointer(this_cptr, this)

    j = 0
    do i = 1, this%p%nat
       do ni = this%seed(i), this%last(i)
          j = j + 1
          i1(j) = i-1
          i2(j) = this%neighbors(ni)-1
          DIST(this%p, this, i, ni, dr(1:3, j), abs_dr(j))
       enddo
    enddo

  endsubroutine f_get_all_neighbors_vec


  !>
  !! Bring a list of scalar per bond information into order
  !<
  subroutine f_pack_per_bond_scalar(this_cptr, r1, r2) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    real(c_double)         :: r1(*)
    real(c_double)         :: r2(*)

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i, ni, j

    ! ---

    call c_f_pointer(this_cptr, this)

    j = 0
    do i = 1, this%p%nat
       do ni = this%seed(i), this%last(i)
          j = j + 1
          r2(j) = r1(ni)
       enddo
    enddo

  endsubroutine f_pack_per_bond_scalar


  !>
  !! Bring a list of 3x3 per bond information into order
  !<
  subroutine f_pack_per_bond_3x3(this_cptr, r1, r2) bind(C)
    use, intrinsic :: iso_c_binding

    implicit none

    type(c_ptr),    value  :: this_cptr
    real(c_double)         :: r1(3,3,*)
    real(c_double)         :: r2(3,3,*)

    type(neighbors_t), pointer  :: this

    ! ---

    integer :: i, ni, j

    ! ---

    call c_f_pointer(this_cptr, this)

    j = 0
    do i = 1, this%p%nat
       do ni = this%seed(i), this%last(i)
          j = j + 1
          r2(1:3,1:3,j) = r1(1:3,1:3,ni)
       enddo
    enddo

  endsubroutine f_pack_per_bond_3x3

endmodule neighbors_wrap
