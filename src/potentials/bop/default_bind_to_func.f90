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
  !! Notify potential of particles, neighbors objects to use in the future
  !<
  subroutine BIND_TO_FUNC(this, p, nl, ierror)
    implicit none
 
    type(BOP_TYPE),    intent(inout) :: this
    type(particles_t), intent(inout) :: p
    type(neighbors_t), intent(inout) :: nl
    integer, optional, intent(out)   :: ierror

    ! ---

    integer          :: i, j, ii, jj, nel, npairs, Z
#ifdef SCREENING
    real(DP)         :: c
#endif

    logical          :: ex(this%db%nel)
    logical          :: expairs(this%db%nel*(this%db%nel+1)/2)
    real(DP)         :: x(this%db%nel*(this%db%nel+1)/2)

    ! ---

    INIT_ERROR(ierror)

    call del(this)

#ifdef SCREENING

    this%Cmin      = this%db%Cmin
    this%Cmax      = this%db%Cmax
    this%dC        = this%Cmax-this%Cmin

    !
    ! The maximum cutoff needs to be the maximum distance and atom can be away
    ! and still considered for screening.
    !
    ! This means there is a scale factor for the distance a screening neighbor
    ! can. It is given by
    !   X = (xik/xij)^2 = C^2/(4*(C-1))
    ! where xij is the bond distance and xik the distance to the screening
    ! neighbor.
    !
    ! Note that at C = 2 the maximum distance is the xik^2 = xij^2 and hence
    ! C_dr_cut = 1.0_DP below. For C < 2 we also need to consider at least
    ! xik^2 = xij^2.
    !

    this%C_dr_cut  = 1.0_DP
    where (this%Cmax > 2.0_DP)
       this%C_dr_cut = this%Cmax**2/(4*(this%Cmax-1))
    endwhere

#endif

    nel    = this%db%nel
    npairs = nel*(nel+1)/2

    this%Z2db = -1
    ex        = .false.
    expairs   = .false.

    do i = 1, this%db%nel
       Z = atomic_number(a2s(this%db%el(:, i)))
       if (Z > 0) then
          this%Z2db(Z)  = i
          ex(i)         = any(p%el2Z(p%el) == Z)
       else
          RAISE_ERROR("Unknown element '" // trim(a2s(this%db%el(:, i))) // "'.", ierror)
       endif
    enddo

    do i = 1, this%db%nel
       do j = 1, this%db%nel
          if (ex(i) .and. ex(j)) then
             expairs(Z2pair(this, i, j)) = .true.
          endif
       enddo
    enddo

    do i = 1, npairs
       this%cut_in_l(i)   = this%db%r1(i)
       this%cut_in_h(i)   = this%db%r2(i)
       this%cut_in_h2(i)  = this%db%r2(i)**2

#ifdef SCREENING
       this%cut_out_l(i)  = this%db%or1(i)
       this%cut_out_h(i)  = this%db%or2(i)

       this%cut_bo_l(i)   = this%db%bor1(i)
       this%cut_bo_h(i)   = this%db%bor2(i)

       this%max_cut_sq(i)   = max( &
            this%cut_in_h(i), &
            this%cut_out_h(i), &
            this%cut_bo_h(i) &
            )**2
#endif
    enddo

    !
    ! Request interaction range for each element pair
    !

#ifdef SCREENING

    x = sqrt(this%C_dr_cut(1:npairs))

#endif

    do i = 1, p%nel
       do j = 1, p%nel
          ii = this%Z2db(p%el2Z(i))
          jj = this%Z2db(p%el2Z(j))
          if (ex(ii) .and. ex(jj)) then
             nel = Z2pair(this, ii, jj)
#ifdef SCREENING
             call request_interaction_range( &
                  nl, &
                  x(nel)*sqrt(this%max_cut_sq(nel)), &
                  i, j &
                  )
#else
             call request_interaction_range( &
                  nl, &
                  this%cut_in_h(nel), &
                  i, j &
                  )
#endif
          endif
       enddo
    enddo

#ifdef SCREENING

    c = max( &
         maxval(x*this%db%r2(1:npairs), mask=expairs), &
         maxval(x*this%db%or2(1:npairs), mask=expairs), &
         maxval(x*this%db%bor2(1:npairs), mask=expairs) &
         )
    call request_border(p, c)

#endif

  endsubroutine BIND_TO_FUNC
