!runs the streamliner for streamlining data
!created by Freddie Rice

      program streamliner 
      use indexing
      implicit none
      
      !internal variables
      double precision,dimension(:),allocatable :: indata,tempData
      integer :: i,j,k
      integer,dimension(:),allocatable :: ord,tempOrd
      
      !data variables
      integer :: rowcount,columncount
      integer :: counter,current
      integer,dimension(:),allocatable :: columns

      !MPI variables
      integer :: ierr, icomm, irank, isize, iinfo
      integer,dimension(MPI_STATUS_SIZE) :: istatus

      allocate(columns(3))
      columns(1) = 1
      columns(2) = 3
      columns(3) = 4

      icomm = MPI_COMM_WORLD
      iinfo = MPI_INFO_NULL
      
      call MPI_INIT(ierr)
      call MPI_COMM_RANK(icomm,irank,ierr)
      call MPI_COMM_SIZE(icomm,isize,ierr)
      call SortByColumn("file.h5", "dataset", columns, 5, 50, irank, isize, icomm, istatus, iinfo)
      
!     !initialize stuff
!     rowcount = 100000
!     allocate(indata(rowcount))
!     allocate(ord(rowcount))
!     
!     
!     call qsorti(ord,rowcount,indata)
!     !iterate over columns
!     do i=2,columncount
!        counter = 0
!        current = 1
!        do j=2,rowcount
!           if( indata(j-1) .eq. indata(j) ) then
!              counter = counter + 1
!              cycle
!           end if
!           if( counter .gt. 1 ) then
!              !make room
!              allocate(tempOrd(counter))
!              allocate(tempData(counter))
!              
!              !copy over data
!              do k=current,current+counter-1
!                 tempOrd(k-current+1) = k-current+1
!                 tempData(k-current+1) = indata(k)
!              end do
!              
!              !sort it
!              call qsorti(tempOrd,counter,tempData)
!              
!              !move back the indexes
!              do k=current,current+counter-1
!                 ord(k) = tempOrd(k-current+1)
!              end do
!              
!              !cleanup
!              deallocate(tempOrd)
!              deallocate(tempData)
!           end if
!        end do
!     end do

      !write the sorted table
      !do j=1,rowcount
      !   write(*,*) "hi"
      !end do      
      
      call MPI_FINALIZE(ierr)

      end program
