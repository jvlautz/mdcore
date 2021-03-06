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

  subroutine REGISTER_FUNC(this, cfg, m)
    use, intrinsic :: iso_c_binding

    implicit none

    type(BOP_TYPE), target      :: this
    type(c_ptr),    intent(in)  :: cfg
    type(c_ptr),    intent(out) :: m

    ! ---

#ifdef SCREENING
    m = ptrdict_register_section(cfg, CSTR(BOP_STR), &
         CSTR("Abell-Tersoff-Brenner type bond-order potential (screened)."))
#else
    m = ptrdict_register_section(cfg, CSTR(BOP_STR), &
         CSTR("Abell-Tersoff-Brenner type bond-order potential."))
#endif

    call ptrdict_register_string_list_property(m, &
         c_loc11(this%db%el), 2, BRENNER_MAX_EL, c_loc(this%db%nel), &
         CSTR("el"), CSTR("List of element symbols."))

    call ptrdict_register_string_property(m, c_loc(this%ref(1)), &
         BRENNER_MAX_REF, &
         CSTR("ref"), &
         CSTR("Reference string to choose a parameters set from the database."))

    call ptrdict_register_list_property(m, &
         c_loc1(this%db%D0), BRENNER_MAX_PAIRS, c_loc(this%db%nD0), &
         CSTR("D0"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%r0), BRENNER_MAX_PAIRS, c_loc(this%db%nr0), &
         CSTR("r0"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%S), BRENNER_MAX_PAIRS, c_loc(this%db%nS), &
         CSTR("S"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%beta), BRENNER_MAX_PAIRS, c_loc(this%db%nbeta), &
         CSTR("beta"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%gamma),BRENNER_MAX_PAIRS,c_loc(this%db%ngamma), &
         CSTR("gamma"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%c), BRENNER_MAX_PAIRS, c_loc(this%db%nc), &
         CSTR("c"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%d), BRENNER_MAX_PAIRS, c_loc(this%db%nd), &
         CSTR("d"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%h), BRENNER_MAX_PAIRS, c_loc(this%db%nh), &
         CSTR("h"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%mu), BRENNER_MAX_PAIRS, c_loc(this%db%nmu), &
         CSTR("mu"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%n), BRENNER_MAX_PAIRS, c_loc(this%db%nn), &
         CSTR("n"), CSTR("See functional form."))
    call ptrdict_register_integer_list_property(m, &
         c_loc1(this%db%m), BRENNER_MAX_PAIRS, c_loc(this%db%nm), &
         CSTR("m"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%r1), BRENNER_MAX_PAIRS, c_loc(this%db%nr1), &
         CSTR("r1"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%r2), BRENNER_MAX_PAIRS, c_loc(this%db%nr2), &
         CSTR("r2"), CSTR("See functional form."))
#ifdef SCREENING
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%or1), BRENNER_MAX_PAIRS, c_loc(this%db%nor1), &
         CSTR("or1"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%or2), BRENNER_MAX_PAIRS, c_loc(this%db%nor2), &
         CSTR("or2"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%bor1), BRENNER_MAX_PAIRS, c_loc(this%db%nbor1), &
         CSTR("bor1"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%bor2), BRENNER_MAX_PAIRS, c_loc(this%db%nbor2), &
         CSTR("bor2"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%Cmin), BRENNER_MAX_PAIRS, c_loc(this%db%nCmin), &
         CSTR("Cmin"), CSTR("See functional form."))
    call ptrdict_register_list_property(m, &
         c_loc1(this%db%Cmax), BRENNER_MAX_PAIRS, c_loc(this%db%nCmax), &
         CSTR("Cmax"), CSTR("See functional form."))
#endif

    call ptrdict_register_integer_property(m, c_loc(this%nebmax), &
         CSTR("nebmax"), CSTR("Maximum number of neighbors (internal neighbor list)."))
    call ptrdict_register_integer_property(m, c_loc(this%nebavg), &
         CSTR("nebavg"), CSTR("Average number of neighbors (internal neighbor list)."))

  endsubroutine REGISTER_FUNC
