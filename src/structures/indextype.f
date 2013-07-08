!a datatype for indexing
!created by Freddie Rice
      
      module IndexType
         implicit none
         type IndexT
            integer :: first, last, swap
         end type

         contains
         
         subroutine emptyIndexT(o)
            implicit none

            !input/output
            type(indext),intent(inout) :: o
            
            o%first = 0
            o%last  = 0
            o%swap  = 0

         end subroutine
         
         function isEmptyIndexT(a) result(o)
            implicit none

            !input/output
            type(indext),intent(inout) :: a
            logical :: o
            
            o = .false.
            if( a%first .ne. 0 ) return
            if( a%last .ne. 0 ) return
            if( a%swap .ne. 0 ) return
            o = .true.

         end function
      end module

