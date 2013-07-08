!Indexes an HDF5 dataset
!Created by Freddie Rice

#define MAX_READ 9
      module indexing
      use hdf5
      use mpi
      use sort
      use QueueObject
      use IndexType
      !use structures
      implicit none
      !include '/stage/mpi/OpenMPI/1.6.2/PGI/12.9/include/mpif.h'
      
      contains
      subroutine Sortbycolumn(filename,datasetname,columns,columncount,rowcount,irank,isize,icomm,istatus,iinfo)
         implicit none

         !input/output
         character(len=*),intent(in) :: filename
         character(len=*),intent(in) :: datasetname
         integer,dimension(:),intent(in) :: columns
         integer,intent(in) :: rowcount
         integer,intent(in) :: columncount

         !MPI variables
         integer,intent(in) :: irank, icomm, isize, iinfo
         integer,dimension(MPI_STATUS_SIZE),intent(in) :: istatus
         integer :: ierr

         !HDF5 Variables
         integer(HID_T) :: fData, fSwap, fIndex
         !integer(HID_T) :: mData_Data, mSwap_Index1, mSwap_Index2, mIndex_Index, mIndex_InputIndex
         integer(HID_T) :: dData_Data, dSwap_Index1, dSwap_Index2, dSwap_Index3, dIndex_Index, dIndex_InputIndex
         integer(HID_T) :: sData_Data, sSwap_Index1, sSwap_Index2, sSwap_Index3, sIndex_Index, sIndex_InputIndex
         integer(HID_T) :: plist_id, sMemory, sMemory2, sLargeMemory
         integer(HSIZE_T),dimension(1) :: dim1, hOffset, hCount
         integer(HSIZE_T),dimension(2) :: dim2, temp2, hOffset2, hCount2
         integer,dimension(3) :: dim3
         integer :: herror
         
         !Serial Merge variables
         double precision,dimension(MAX_READ) :: chunk1, chunk2
         integer(HID_T) :: dSwapIn1, dSwapIn2, dSwapOut
         integer(HID_T) :: sSwapIn1, sSwapIn2, sSwapOut
         integer(HID_T),dimension(3) :: datasets, spaces
         character(len=6) :: datasetIn1, datasetIn2, datasetOut
         integer :: currentWrite, currentRead1, currentRead2, indexIn1, indexIn2, indexOut
         integer :: currentReadMax1, currentReadMax2, currentWriteMax

         !temporary variables
         double precision,dimension(MAX_READ) :: chunk
         integer,dimension(MAX_READ) :: chunkIndex
         integer,dimension(3,MAX_READ) :: ord
         integer(HSIZE_T),dimension(2,MAX_READ) :: coords
         integer(HSIZE_T) :: numcoords
         double precision,dimension(:,:),allocatable :: dat
         integer :: i,j,k
         integer :: currentMin, currentMax, currentSize, currentColumn
         integer :: minimum, maximum, mSize, irate, chunks
         integer :: itemp
         real :: rtemp
          
         !Structures
         type(QueueT) :: queue
         type(IndexT) :: it1, it2, it3

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!     Initialize HDF5 Files     !!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         !open interface
         call h5open_f(herror) 
         
         !open the data file
         call h5pcreate_f(H5P_FILE_ACCESS_F, plist_id, herror) 
         call h5pset_fapl_mpio_f(plist_id, icomm, iinfo, herror) 
         
         !call h5fopen_f(filename, H5F_ACC_RDWR_F, fData, herror, access_prp=plist_id) 
         call h5fcreate_f(filename, H5F_ACC_TRUNC_F, fData, herror, access_prp=plist_id) 
         call h5pclose_f(plist_id,herror)
          
         !create the swap file
         call h5pcreate_f(H5P_FILE_ACCESS_F, plist_id, herror) 
         call h5pset_fapl_mpio_f(plist_id, icomm, iinfo, herror) 
         call h5fcreate_f("Swap.h5", H5F_ACC_TRUNC_F, fSwap, herror, access_prp=plist_id) 
         call h5pclose_f(plist_id,herror)
         
         !create the index file
         call h5pcreate_f(H5P_FILE_ACCESS_F, plist_id, herror) 
         call h5pset_fapl_mpio_f(plist_id, icomm, iinfo, herror) 
         call h5fcreate_f("Index.h5", H5F_ACC_TRUNC_F, fIndex, herror, access_prp=plist_id) 
         call h5pclose_f(plist_id,herror)
         
         !create dataspaces
         dim1 = rowcount
         dim2 = (/columncount,rowcount/)
         call h5screate_simple_f(1, dim1, sSwap_Index1, herror)
         call h5screate_simple_f(1, dim1, sSwap_Index2, herror)
         call h5screate_simple_f(1, dim1, sSwap_Index3, herror)
         call h5screate_simple_f(1, dim1, sIndex_Index, herror)
         call h5screate_simple_f(2, dim2, sData_Data, herror)
         
         !create datasets
         call h5dcreate_f(fData, datasetname, H5T_NATIVE_DOUBLE, sData_Data,dData_Data, herror)
         call h5dcreate_f(fSwap, "Index1", H5T_NATIVE_INTEGER, sSwap_Index1,dSwap_Index1, herror)
         call h5dcreate_f(fSwap, "Index2", H5T_NATIVE_INTEGER, sSwap_Index2,dSwap_Index2, herror)
         call h5dcreate_f(fSwap, "Index3", H5T_NATIVE_INTEGER, sSwap_Index3,dSwap_Index3, herror)
         call h5dcreate_f(fIndex, "Index", H5T_NATIVE_INTEGER, sIndex_Index,dIndex_Index, herror)
         datasets = (/dSwap_Index1,dSwap_Index2,dSwap_Index3/)

         !close dataspaces
         call h5sclose_f(sData_Data, herror)
         call h5sclose_f(sSwap_Index1, herror)
         call h5sclose_f(sSwap_Index2, herror)
         call h5sclose_f(sSwap_Index3, herror)
         call h5sclose_f(sIndex_Index, herror)
   
         !initialize some hyper data
         !dim2Count  = (/,1/)
         !dim2Offset = (/irank,0/)
         !dim2Block  = (/1,columnCount/)


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!    Write random data into dataset     !!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         !create index table of dim 1 by rowcount
         if( irank .eq. 0 ) then
         call h5dget_space_f(dData_Data, sData_Data, herror)
         call h5screate_simple_f(2, dim2, sMemory, herror)
         allocate(dat(dim2(1), dim2(2)))
         do i=1,columnCount
            do j=1,rowCount
               dat(i,j) = mod(3767*j + 3761*i,173)
            end do
         end do
         call h5dwrite_f(dData_Data, H5T_NATIVE_DOUBLE, dat, dim2, herror, mem_space_id=sMemory, file_space_id=sData_Data)
         call h5sclose_f(sMemory,herror)
         call h5sclose_f(sData_Data,herror)
         deallocate(dat)
         print *, "Done writing data.."
         end if

         !wait for first thread to write data
         call MPI_Barrier(icomm, ierr)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!  Create Chunked Sorted Lists  !!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

         !define dataspace for processor
         irate = rowcount/isize
         minimum = irank*irate + 1
         maximum = minimum + irate - 1
         if( irank .eq. isize - 1 ) maximum = rowcount
         mSize = maximum - minimum + 1
         
         !find the number of read chunks within the processor's space
         rtemp = real(mSize)/real(MAX_READ)
         chunks = int(rtemp)
         
         if( real(chunks) .ne. rtemp ) then 
            chunks = chunks + 1
            dim1(1) = mod(mSize, MAX_READ) 
            call h5screate_simple_f(1, dim1, sMemory, herror)
         end if

         dim1(1) = MAX_READ
         call h5screate_simple_f(1, dim1, sLargeMemory, herror)
         
         ord(1,:) = 1
         hCount(1) = MAX_READ
         hOffset(1) = irate*irank
         call h5dget_space_f(dSwap_Index1, sSwap_Index1, herror)
         call h5dget_space_f(dSwap_Index2, sSwap_Index2, herror)
         call h5dget_space_f(dSwap_Index3, sSwap_Index3, herror)
         do i=1,chunks
            !create index table of dim 1 by rowcount
            if( chunks .eq. i ) then
               currentSize = mSize-MAX_READ*(i-1)
               currentMin = minimum + (i-1)*MAX_READ
               currentMax = currentMin + currentSize - 1
               dim1(1) = currentSize
               hCount = currentSize
               do j=currentMin, currentMax
                  ord(1,j-currentMin + 1) = j
               end do
               call h5screate_simple_f(1, dim1, sMemory, herror)
               call h5sselect_hyperslab_f(sSwap_Index1, H5S_SELECT_SET_F, hOffset, hCount, herror)
               call h5sselect_hyperslab_f(sSwap_Index2, H5S_SELECT_SET_F, hOffset, hCount, herror)
               call h5sselect_hyperslab_f(sSwap_Index3, H5S_SELECT_SET_F, hOffset, hCount, herror)
               call h5dwrite_f(dSwap_Index1,H5T_NATIVE_INTEGER, ord(1,:), dim1, herror, mem_space_id=sMemory, file_space_id=sSwap_Index1)
               call h5dwrite_f(dSwap_Index2,H5T_NATIVE_INTEGER, ord(1,:), dim1, herror, mem_space_id=sMemory, file_space_id=sSwap_Index2)
               call h5dwrite_f(dSwap_Index3,H5T_NATIVE_INTEGER, ord(1,:), dim1, herror, mem_space_id=sMemory, file_space_id=sSwap_Index3)
               call h5sclose_f(sMemory,herror)
               exit
            end if
            currentMin = (i-1)*MAX_READ + minimum
            currentMax = i*MAX_READ + minimum - 1
            do j=currentMin, currentMax
               ord(1,j-currentMin + 1) = j
            end do
            call h5sselect_hyperslab_f(sSwap_Index1, H5S_SELECT_SET_F, hOffset, hCount, herror)
            call h5sselect_hyperslab_f(sSwap_Index2, H5S_SELECT_SET_F, hOffset, hCount, herror)
            call h5sselect_hyperslab_f(sSwap_Index3, H5S_SELECT_SET_F, hOffset, hCount, herror)
            call h5dwrite_f(dSwap_Index1,H5T_NATIVE_INTEGER, ord(1,:), dim1, herror,mem_space_id=sLargeMemory,file_space_id=sSwap_Index1)
            call h5dwrite_f(dSwap_Index2,H5T_NATIVE_INTEGER, ord(1,:), dim1, herror,mem_space_id=sLargeMemory,file_space_id=sSwap_Index2)
            call h5dwrite_f(dSwap_Index3,H5T_NATIVE_INTEGER, ord(1,:), dim1, herror,mem_space_id=sLargeMemory,file_space_id=sSwap_Index3)
            hOffset(1) = hOffset(1) + MAX_READ
         end do

         call h5sclose_f(sSwap_Index1,herror)
         call h5sclose_f(sSwap_Index2,herror)
         call h5sclose_f(sSwap_Index3,herror)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!     Sort Preliminary Data     !!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         print *, "Sort Preliminary Data"
         !initialize the first column in easily accessed memory
         currentColumn = columns(1)
         
         call h5dget_space_f(dSwap_Index1,sSwap_Index1, herror)
         call h5dget_space_f(dData_Data,SData_Data, herror)
         dim1(1) = MAX_READ
         call h5screate_simple_f(1,dim1,sMemory,herror)
         coords(1,:) = currentColumn
         currentSize = MAX_READ
         
         do i=1,chunks
            currentMin = minimum + MAX_READ*(i-1)
            if( chunks .eq. i ) then
               ord(1,:) = currentColumn
               coords(1,:) = currentColumn
               currentMax = maximum
               currentSize = currentMax - currentMin + 1
               dim1(1) = currentSize
               call h5sclose_f(sMemory,herror)
               call h5screate_simple_f(1,dim1,sMemory,herror)
            else
               currentMax = currentMin + MAX_READ - 1
               currentSize = currentMax - currentMin + 1
            end if
            
            hCount(1) = currentSize
            hOffset(1) = currentMin-1
            call h5sselect_hyperslab_f(sSwap_Index1, H5S_SELECT_SET_F, hOffset, hCount, herror)
            call h5dread_f(dSwap_Index1,H5T_NATIVE_INTEGER,ord(2,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwap_Index1)
            numCoords = currentSize
            do j=1,currentSize
               coords(2,j) = ord(2,j)
            end do
            call h5sselect_elements_f(sData_Data, H5S_SELECT_SET_F, 2, numCoords, coords, herror)
            call h5dread_f(dData_Data,H5T_NATIVE_DOUBLE,chunk,dim1,herror,mem_space_id=sMemory,file_space_id=sData_Data)
            call QSORTI(ord(1,:),currentSize,chunk)
            do j=1,currentSize 
               ord(1,j) = ord(2,ord(1,j))
            end do
            call h5dwrite_f(dSwap_Index1,H5T_NATIVE_INTEGER,ord(1,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwap_Index1)

         end do

         call h5sclose_f(sSwap_Index1,herror)
         call h5sclose_f(sData_Data,herror)
         call h5sclose_f(sMemory,herror)
         

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!  Sort the chunks into single processor block  !!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         
         !initialize queue with more than it needs to increase efficiency
         queue = NewQueue(2*chunks + 2)
         
         !initialize the spaces
         call h5dget_space_f(dSwap_Index1,sSwap_Index1, herror)
         call h5dget_space_f(dSwap_Index2,sSwap_Index2, herror)
         call h5dget_space_f(dSwap_Index3,sSwap_Index3, herror)
         spaces   = (/sSwap_Index1,sSwap_Index2,sSwap_Index3/)
         
         !fill the queue
         print *, "Chunks: ", chunks
         do i=1,chunks
            it1%swap = 1
            it1%first  = minimum + MAX_READ*(i-1)
            if( i .ne. chunks) then
               it1%last = it1%first + MAX_READ - 1
            else
               it1%last = maximum
            end if
            call enqueue(it1, queue)
         end do

         !sort the indexes in the queue
         do while( QueueCardinality(queue) .ne. 1 )
            
            !pull indeces from queue
            call dequeue(queue, it1)
            call dequeue(queue, it2)
            
            !if the numbers came in the wrong order
            do while( .true. ) 
               if(it1%first .gt. it2%first) then 
                  it3 = it1
                  it1 = it2
                  it2 = it3
               end if
               if(it1%last + 1 .ne. it2%first) then
                  call enqueue(it2, queue)
                  call dequeue(queue, it2)
               else
                  exit
               end if
            end do
            
            !decides which index file to read/write from
            dim3 = 1
            call setSwap(it1%swap, datasetIn1, dim3)
            call setSwap(it2%swap, datasetIn2, dim3)
            
            !set current datasets/spaces
            dSwapIn1 = datasets(it1%swap)
            dSwapIn2 = datasets(it2%swap)
            dSwapOut = datasets(it3%swap)
            sSwapIn1 = spaces(it1%swap)
            sSwapIn2 = spaces(it2%swap)
            sSwapOut = spaces(it3%swap)
            
            !set the new index type
            it3%first = it1%first
            it3%last = it2%last
            do i=1,3
               if( dim3(i) .eq. 1 ) then
                  it3%swap = i
                  call setSwap(i, datasetOut, dim3)
                  exit
               end if
            end do

            print *, it1%first, it1%last, it2%first, it2%last, it1%swap, it2%swap, it3%swap

            !wee bit of a hack to initialize the loop
            indexIn1 = MAX_READ + 1
            indexIn2 = MAX_READ + 1
            indexOut = 1
            currentRead1 = it1%first - MAX_READ
            currentRead2 = it2%first - MAX_READ
            currentWrite = it3%first
            currentReadMax1 = it1%last
            currentReadMax2 = it2%last
            currentWriteMax = it3%last
            
            dim1(1) = MAX_READ
            call h5screate_simple_f(1, dim1, sMemory, herror)
            do while(.true.)
               !refill the buffer if it is empty
               if( indexIn1 .gt. MAX_READ ) then
                  print *, "need refill index1"
                  indexIn1 = 1
                  currentRead1 = currentRead1 + MAX_READ
                  if( currentRead1 .gt. currentReadMax1 ) exit
                  if( currentRead1 + MAX_READ .gt. currentReadMax1 ) then 
                     !read only the correct amount
                     hCount(1) = currentReadMax1 - currentRead1 + 1
                     dim1(1) = hCount(1)
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  else
                     hCount(1) = MAX_READ
                  end if
                  hOffset(1) = currentRead1 - 1

                  call h5sselect_hyperslab_f(sSwapIn1, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dread_f(dSwapIn1,H5T_NATIVE_INTEGER,ord(1,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapIn1)
                  numCoords = hCount(1)
                  do j=1,numCoords
                     coords(2,j) = ord(1,j)
                  end do
                  call h5sselect_elements_f(sData_Data, H5S_SELECT_SET_F, 2, numCoords, coords, herror)
                  call h5dread_f(dData_Data,H5T_NATIVE_DOUBLE,chunk1,dim1,herror,mem_space_id=sMemory,file_space_id=sData_Data)
                  
                  !reset sMemory if it was changed
                  if( hCount(1) .ne. MAX_READ ) then
                     dim1(1) = MAX_READ
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  end if
               end if
                  
               !refill the buffer if it is empty
               if( indexIn2 .gt. MAX_READ ) then
                  print *, "need refill index2"
                  indexIn2 = 1
                  currentRead2 = currentRead2 + MAX_READ
                  if( currentRead2 .gt. currentReadMax2 ) exit
                  if( currentRead2 + MAX_READ .gt. currentReadMax2 ) then 
                     !read only the correct amount
                     hCount(1) = currentReadMax2 - currentRead2 + 1
                     dim1(1) = hCount(1)
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  else
                     hCount(1) = MAX_READ
                  end if
                  hOffset(1) = currentRead2 - 1

                  call h5sselect_hyperslab_f(sSwapIn2, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dread_f(dSwapIn2,H5T_NATIVE_INTEGER,ord(2,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapIn2)
                  numCoords = hCount(1)
                  do j=1,numCoords
                     coords(2,j) = ord(2,j)
                  end do
                  call h5sselect_elements_f(sData_Data, H5S_SELECT_SET_F, 2, numCoords, coords, herror)
                  call h5dread_f(dData_Data,H5T_NATIVE_DOUBLE,chunk2,dim1,herror,mem_space_id=sMemory,file_space_id=sData_Data)

                  !reset sMemory if it was changed
                  if( hCount(1) .ne. MAX_READ ) then
                     dim1(1) = MAX_READ
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  end if
               end if
               
               !Write out the buffer if it is full
               if( indexOut .gt. MAX_READ ) then
                  print *, "dumping indexOut"
                  indexOut = 1
                  
                  if( currentWrite + MAX_READ .gt. currentWriteMax ) then
                     dim1(1) = currentWriteMax - currentWrite + 1
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  else
                     dim1(1) = MAX_READ
                  end if
                  
                  hCount(1) = dim1(1)
                  hOffset(1) = currentWrite - 1
                  call h5sselect_hyperslab_f(sSwapOut, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dwrite_f(dSwapOut,H5T_NATIVE_INTEGER,ord(3,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapOut)
                  
                  !reset sMemory if it was changed
                  currentWrite = currentWrite + MAX_READ
                  if( currentWrite .gt. currentWriteMax ) then
                     dim1(1) = MAX_READ
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  end if
               end if

               !select the lowest element and put it in place
               if( chunk1(ord(1,indexIn1)) .lt. chunk2(ord(2,indexIn2)) ) then
                  ord(3,indexOut) = ord(1,indexIn1)
                  indexIn1 = indexIn1 + 1
               else
                  ord(3,indexOut) = ord(2,indexIn2)
                  indexIn2 = indexIn2 + 1
               end if
               indexOut = indexOut + 1
               
            end do !end merging
            
            !write out the leftovers in the out buffer   
            if( indexOut .ne. 1 ) then
               dim1(1) = indexOut - 1
               call h5sclose_f(sMemory, herror)
               call h5screate_simple_f(1, dim1, sMemory, herror)
               hCount(1) = dim1(1)
               hOffset(1) = currentWrite - 1
               call h5sselect_hyperslab_f(sSwapOut, H5S_SELECT_SET_F, hOffset, hCount, herror)
               call h5dwrite_f(dSwapOut,H5T_NATIVE_INTEGER,ord(3,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapOut)
               currentWrite = currentWrite + indexOut - 1
            end if
            
            if( indexIn1 .gt. MAX_READ ) then
               if( indexIn2 .ne. 1 ) then
                  dim1(1) = indexIn2 - 1
                  call h5sclose_f(sMemory, herror)
                  call h5screate_simple_f(1, dim1, sMemory, herror)
                  hCount(1) = dim1(1)
                  hOffset(1) = currentWrite - 1
                  call h5sselect_hyperslab_f(sSwapOut, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dwrite_f(dSwapOut,H5T_NATIVE_INTEGER,ord(2,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapOut)
                  currentWrite = currentWrite + indexIn2 - 1
               end if
               dim1(1) = MAX_READ
               call h5sclose_f(sMemory, herror)
               call h5screate_simple_f(1, dim1, sMemory, herror)
               do while( currentRead2 .le. currentReadMax2 )
                  if( currentRead2 + MAX_READ .gt. currentReadMax2 ) then 
                     hCount(1) = currentReadMax2 - currentRead2 + 1
                     dim1(1) = hCount(1)
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  end if
                  
                  hCount(1) = dim1(1)
                  hOffset(1) = currentWrite - 1
                  call h5sselect_hyperslab_f(sSwapOut, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dwrite_f(dSwapOut,H5T_NATIVE_INTEGER,ord(2,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapOut)

                  currentWrite = currentWrite + MAX_READ
                  currentRead2 = currentRead2 + MAX_READ
               end do
            else
               if( indexIn1 .ne. 1 ) then
                  dim1(1) = indexIn1 - 1
                  call h5sclose_f(sMemory, herror)
                  call h5screate_simple_f(1, dim1, sMemory, herror)
                  hCount(1) = dim1(1)
                  hOffset(1) = currentWrite - 1
                  call h5sselect_hyperslab_f(sSwapOut, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dwrite_f(dSwapOut,H5T_NATIVE_INTEGER,ord(1,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapOut)
                  currentWrite = currentWrite + indexIn1 - 1
               end if
               dim1(1) = MAX_READ
               call h5sclose_f(sMemory, herror)
               call h5screate_simple_f(1, dim1, sMemory, herror)
               do while( currentRead1 .le. currentReadMax1 )
                  if( currentRead1 + MAX_READ .gt. currentReadMax1 ) then 
                     hCount(1) = currentReadMax1 - currentRead1 + 1
                     dim1(1) = hCount(1)
                     call h5sclose_f(sMemory, herror)
                     call h5screate_simple_f(1, dim1, sMemory, herror)
                  end if
                  
                  hCount(1) = dim1(1)
                  hOffset(1) = currentWrite - 1
                  call h5sselect_hyperslab_f(sSwapOut, H5S_SELECT_SET_F, hOffset, hCount, herror)
                  call h5dwrite_f(dSwapOut,H5T_NATIVE_INTEGER,ord(1,:),dim1,herror,mem_space_id=sMemory,file_space_id=sSwapOut)

                  currentWrite = currentWrite + MAX_READ
                  currentRead2 = currentRead2 + MAX_READ
               end do
            end if
            call h5sclose_f(sMemory, herror)
            call enqueue(it3,queue)
         end do !end all merges
         
         print *, "disposing queue"
         call DisposeQueue(queue)
         
         !cleanup
         call h5sclose_f(sSwap_Index1,herror)
         call h5sclose_f(sSwap_Index2,herror)
         call h5sclose_f(sSwap_Index3,herror)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!  The master delegates a parallel merge sort  !!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!        !setup parallel access
!        call h5pcreate_f(H5P_FILE_ACCESS_F, plist_id, herror)
!        call h5pset_fapl_mpio_f(plist_id, icomm, info, herror)

!        !open file
!        call h5fopen_f(filename, H5F_ACC_RDONLY_F, hdf_file, hdferr)
!        
!        !create the index dataset
!        h5screate_

!        do i=1,chunks
!           !open the index dataset
!           !read first chunk
!           !if index dataset is empty
!              !write sorted data to it
!           !else
!              !mergewrite data to it
!           !close the dataspace
!        end do

!        !hdf5 close file
!        call h5fclose_f(hdf_file)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!      Close the HDF5 files and interface      !!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


         print *, "close dataspaces"
         !close dataspaces
         call h5sclose_f(sLargeMemory, herror)
         
         print *, "close all datasets"
         !close all datasets
         call h5dclose_f(dSwap_Index1, herror)
         call h5dclose_f(dSwap_Index2, herror)
         call h5dclose_f(dSwap_Index3, herror)
         call h5dclose_f(dData_Data, herror)
         call h5dclose_f(dIndex_Index, herror)

         print *, "close files"
         !close files
         call h5fclose_f(fData,herror)
         call h5fclose_f(fSwap,herror)
         call h5fclose_f(fIndex,herror)
        
         print *, "close interface"
         
         !hdf5 interface
         call h5close_f(herror)

      end subroutine 
      
      subroutine setSwap(swap,ident,dims) 
         implicit none

         !input/output
         integer,intent(inout) :: swap
         character(len=*),intent(inout) :: ident
         integer,dimension(:),intent(inout) :: dims

         select case( swap )
            case(1)
               ident = "Index1"
               dims(1) = 0
            case(2)
               ident =  "Index2"
               dims(2) = 0
            case(3)
               ident = "Index3"
               dims(3) = 0
         end select

      end subroutine

      end module
