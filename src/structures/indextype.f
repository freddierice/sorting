!a datatype for indexing
!created by Freddie Rice

      module IndexType
         implicit none
         type IndexT
            integer :: first, second
            logical :: onFirst
         end type
      end module

