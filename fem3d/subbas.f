c
c $Id: subbas.f,v 1.4 2009-04-03 16:38:23 georg Exp $
c
c initialization routines
c
c contents :
c
c subroutine sp13test(nb,nvers)			tests if file is BAS file
c subroutine sp13rr(nb,nknddi,nelddi)		unformatted read from lagoon
c subroutine sp13uw(nb)				unformatted write to lagoon
c subroutine sp13ts(nvers,nb,n)			test write to unit nb
c
c revision log :
c
c 31.05.1997	ggu	unnecessary routines deleted
c 27.06.1997	ggu	bas routines into own file
c 02.04.2009	ggu	error messages changed
c 12.01.2011	ggu	debug routine introduced (sp13ts)
c 23.10.2014	ggu	introduced ftype and nvers = 4
c 04.01.2015	ggu	new routine sp13_get_par()
c 31.03.2015	ggu	set iarnv on read
c 25.05.2015	ggu	module introduced
c 02.10.2015	ggu	in basin_open_file eliminated double read (bug)
c 02.10.2015	ggu	new routines is_depth_unique(), estimate_ngr()
c 01.05.2016	ggu	new routines basin_has_basin()
c 20.05.2016	ggu	estimate_ngr() returns exact ngr
c 10.06.2016	ggu	new routine for inserting regular grid
c 23.09.2016	ggu	new routines to check if basin has been read
c 06.12.2016	ggu	new framework to deal with 1d elements
c
c***********************************************************
c***********************************************************
c***********************************************************

!==================================================================
        module basin
!==================================================================

        implicit none

	logical, parameter :: enable_1d = .true. !true if 1d needed

	logical, save :: has_1d = .false.	!true if 1d found

        integer, private, save :: nkn_basin = 0
        integer, private, save :: nel_basin = 0

        logical, private, save :: bbasinread = .false.	! basin has been read

        integer, save :: nkn = 0
        integer, save :: nel = 0
        integer, save :: ngr = 0
        integer, save :: mbw = 0

        integer, save :: nel_2d = 0	!2d elements (3 vertices)
        integer, save :: nel_tot = 0	!total elements

        integer, save :: nkndi = 0	!these are needed when nkn changes
        integer, save :: neldi = 0
        !integer, save :: ngrdi = 0
        !integer, save :: mbwdi = 0

        real, save :: dcorbas = 0.
        real, save :: dirnbas = 0.

        character*80, save :: descrr = ' '

        integer, save, allocatable :: nen3v(:,:)
        integer, save, allocatable :: ipev(:)
        integer, save, allocatable :: ipv(:)
        integer, save, allocatable :: iarv(:)
        integer, save, allocatable :: iarnv(:)

        real, save, allocatable :: xgv(:)
        real, save, allocatable :: ygv(:)
        real, save, allocatable :: hm3v(:,:)

        real, save, allocatable :: widev(:)

        INTERFACE		 basin_read
        MODULE PROCEDURE 
     +				 basin_read_by_file
     +				,basin_read_by_unit
        END INTERFACE

        INTERFACE		 basin_is_basin
        MODULE PROCEDURE
     +				 basin_is_basin_by_file
     +				,basin_is_basin_by_unit
        END INTERFACE

        INTERFACE		 basin_element_average
        MODULE PROCEDURE
     +				 basin_element_average_2d_r
     +				,basin_element_average_2d_d
     +				,basin_element_average_3d
        END INTERFACE

        INTERFACE		 basin_element_average2
        MODULE PROCEDURE
     +				 basin_element_average_2d_2var
        END INTERFACE

        INTERFACE		 basin_vertex_average
        MODULE PROCEDURE
     +				 basin_vertex_average_2d
     +				,basin_vertex_average_2d_minmax
        END INTERFACE

	PRIVATE ::
     +				 basin_read_by_file
     +				,basin_read_by_unit
	PRIVATE ::
     +				 basin_is_basin_by_file
     +				,basin_is_basin_by_unit
	PRIVATE :: 
     +				 basin_element_average_2d_r
     +				,basin_element_average_2d_d
     +				,basin_element_average_3d
	PRIVATE ::
     +				 basin_element_average_2d_2var
	PRIVATE ::
     +				 basin_vertex_average_2d
     +				,basin_vertex_average_2d_minmax

!==================================================================
        contains
!==================================================================

	subroutine basin_init(nk,ne)

	integer nk,ne

	if( nk == nkn_basin .and. ne == nel_basin ) return

        if( ne > 0 .or. nk > 0 ) then
          if( ne == 0 .or. nk == 0 ) then
            write(6,*) 'nel,nkn: ',ne,nk
            stop 'error stop basin_init: incompatible parameters'
          end if
        end if

	if( nkn_basin > 0 ) then
	  deallocate(nen3v)
	  deallocate(ipev)
	  deallocate(ipv)
	  deallocate(iarv)
	  deallocate(iarnv)
	  deallocate(xgv)
	  deallocate(ygv)
	  deallocate(hm3v)
	  deallocate(widev)
	end if

	nkn = nk
	nel = ne
	nkndi = nk
	neldi = ne
	nkn_basin = nk
	nel_basin = ne

	if( nk == 0 ) return

	allocate(nen3v(3,nel))
	allocate(ipev(nel))
	allocate(ipv(nkn))
	allocate(iarv(nel))
	allocate(iarnv(nkn))
	allocate(xgv(nkn))
	allocate(ygv(nkn))
	allocate(hm3v(3,nel))
	allocate(widev(nel))

	end subroutine basin_init

c***********************************************************

	function basin_open_file(file)

! opens file or returns 0
	
	integer basin_open_file
	character*(*) file

	integer iunit,ios
	integer ifileo

	basin_open_file = 0

	iunit = ifileo(0,file,'unform','old')
	if( iunit .le. 0 ) return
	!open(iunit,file=file,status='old',form='unformatted',iostat=ios)
	!if( ios /= 0 ) return

	basin_open_file = iunit

	end function basin_open_file

c***********************************************************

	subroutine basin_read_by_file(file)

! reads basin or fails if error

	character*(*) file

	integer iunit

	iunit = basin_open_file(file)

	if( iunit .le. 0 ) then
	  write(6,*) 'file: ',trim(file)
	  stop 'error stop basin_read_by_file: cannot open file'
	end if

	call basin_read_by_unit(iunit)

	close(iunit)

	write(6,*) 'finished reading basin: ',trim(file)

	end subroutine basin_read_by_file

c***********************************************************

	subroutine basin_read_by_unit(iunit)

! reads basin or fails if error

	integer iunit

	integer nk,ne

	call sp13_get_par(iunit,nk,ne,ngr,mbw)
	call basin_init(nk,ne)			!here we set nkn, nel
	rewind(iunit)
	call sp13rr(iunit,nkn,nel)
	call sp13_set_1d
	bbasinread = .true.
	!write(6,*) 'finished basin_read (module)'

	end subroutine basin_read_by_unit

c***********************************************************

	subroutine basin_set_read_basin(bread)

! sets flag if basin has been read

	logical bread

	bbasinread = bread

	end subroutine basin_set_read_basin

c***********************************************************

	function basin_has_read_basin()

! checks if basin has been read

	logical basin_has_read_basin

	basin_has_read_basin = bbasinread

	end function basin_has_read_basin

c***********************************************************

	function basin_has_basin()

! checks if basin is available (not necessarily read)

	logical basin_has_basin

	basin_has_basin = nkn_basin > 0 .and. nel_basin > 0

	end function basin_has_basin

c***********************************************************

	subroutine basin_get_dimension(nk,ne)

! returns dimension of arrays (already allocated)

	integer nk,ne

	nk = nkndi
	ne = neldi

	end subroutine basin_get_dimension

c***********************************************************

	function basin_is_basin_by_unit(iunit)

	logical basin_is_basin_by_unit
	integer iunit

	integer nvers

	call sp13test(iunit,nvers)

	basin_is_basin_by_unit = nvers > 0

	end function basin_is_basin_by_unit

c***********************************************************

	function basin_is_basin_by_file(file)

	logical basin_is_basin_by_file
	character*(*) file

	integer iunit

	basin_is_basin_by_file = .false.

	iunit = basin_open_file(file)
	if( iunit .le. 0 ) return

	basin_is_basin_by_file = basin_is_basin_by_unit(iunit)

	close(iunit)

	end function basin_is_basin_by_file

c***********************************************************
c***********************************************************
c***********************************************************
c utility functions (for inlining)
c***********************************************************
c***********************************************************
c***********************************************************

	pure subroutine basin_element_average_2d_2var(ie,v1,v2,r1,r2)

	integer, intent(in)		:: ie
	real, intent(in)		:: v1(nkn)
	real, intent(in)		:: v2(nkn)
	real, intent(out)		:: r1,r2

	integer ii,n,k
	real aver

	n = basin_get_vertex_of_element(ie)

	r1 = 0.
	r2 = 0.
	do ii=1,n
	  k = nen3v(ii,ie)
	  r1 = r1 + v1(k)
	  r2 = r2 + v2(k)
	end do
	r1 = r1 / n
	r2 = r2 / n

	end subroutine basin_element_average_2d_2var

c***********************************************************

	pure function basin_element_average_2d_r(ie,value)

	real				:: basin_element_average_2d_r
	integer, intent(in)		:: ie
	real, intent(in)		:: value(nkn)

	integer ii,n
	real aver

	n = basin_get_vertex_of_element(ie)

	aver = 0.
	do ii=1,n
	  aver = aver + value(nen3v(ii,ie))
	end do
	aver = aver / n

	basin_element_average_2d_r = aver

	end function basin_element_average_2d_r

c***********************************************************

	pure function basin_element_average_2d_d(ie,value)

	real				:: basin_element_average_2d_d
	integer, intent(in)		:: ie
	double precision, intent(in)	:: value(nkn)

	integer ii,n
	double precision aver

	n = basin_get_vertex_of_element(ie)

	aver = 0.
	do ii=1,n
	  aver = aver + value(nen3v(ii,ie))
	end do
	aver = aver / n

	basin_element_average_2d_d = aver

	end function basin_element_average_2d_d

c***********************************************************

	pure function basin_element_average_3d(nlvddi,l,ie,value)

	real				:: basin_element_average_3d
	integer, intent(in)		:: nlvddi
	integer, intent(in)		:: l
	integer, intent(in)		:: ie
	real, intent(in)		:: value(nlvddi,nkn)

	integer ii,n
	real aver

	n = basin_get_vertex_of_element(ie)

	aver = 0.
	do ii=1,n
	  aver = aver + value(l,nen3v(ii,ie))
	end do
	aver = aver / n

	basin_element_average_3d = aver

	end function basin_element_average_3d

c***********************************************************

	pure function basin_vertex_average_2d(ie,val3)

	real			:: basin_vertex_average_2d
	integer, intent(in)	:: ie
	real, intent(in)	:: val3(3,nel)

	if( basin_element_is_1d(ie) ) then
	  basin_vertex_average_2d = (val3(1,ie)+val3(2,ie))/2.
	else
	  basin_vertex_average_2d = (val3(1,ie)+val3(2,ie)+val3(3,ie))/3.
	end if
	  
	end function basin_vertex_average_2d

c***********************************************************

	pure function basin_vertex_average_2d_minmax(mode,ie,val3)

	real			:: basin_vertex_average_2d_minmax
	integer, intent(in)	:: mode
	integer, intent(in)	:: ie
	real, intent(in)	:: val3(3,nel)

	integer n
	real val

	n = basin_get_vertex_of_element(ie)

	if( mode > 0 ) then
	  val = maxval(val3(1:n,ie))
	else if( mode < 0 ) then
	  val = minval(val3(1:n,ie))
	else
	  val = basin_vertex_average_2d(ie,val3)
	end if
	  
	basin_vertex_average_2d_minmax = val

	end function basin_vertex_average_2d_minmax

c***********************************************************
c***********************************************************
c***********************************************************

	pure subroutine basin_get_vertex_nodes(ie,n,kn)

	integer, intent(in)		:: ie
	integer, intent(out)		:: n
	integer, intent(out)		:: kn(:)

	n = basin_get_vertex_of_element(ie)

	kn(1:n) = nen3v(1:n,ie)

	end subroutine basin_get_vertex_nodes

c***********************************************************

	pure function basin_get_vertex_of_element(ie)

	integer				:: basin_get_vertex_of_element
	integer, intent(in)		:: ie

	if( enable_1d .and. has_1d ) then
	  if( nen3v(3,ie) == 0 ) then
	    basin_get_vertex_of_element = 2
	  else
	    basin_get_vertex_of_element = 3
	  end if
	else
	  basin_get_vertex_of_element = 3
	end if

	end function basin_get_vertex_of_element

c***********************************************************

	pure function basin_element_is_1d(ie)

	logical				:: basin_element_is_1d
	integer, intent(in)		:: ie

	if( enable_1d .and. has_1d ) then
	  basin_element_is_1d = ( nen3v(3,ie) == 0 )
	else
	  basin_element_is_1d = .false.
	end if

	end function basin_element_is_1d

c***********************************************************

	pure function basin_has_1d()

	logical				:: basin_has_1d

	basin_has_1d = has_1d

	end function basin_has_1d

c***********************************************************
c***********************************************************
c***********************************************************

        pure function link_is_k(ii,ie,k)

! true if nen3v(ii,ie) is k

        logical link_is_k
        integer, intent(in) :: ii,ie,k

        link_is_k = ( nen3v(ii,ie) == k )

        end function link_is_k

!***********************************************************

        pure function kiithis(ii,ie)

! gets node at position ii in ie

	integer		    :: kiithis
        integer, intent(in) :: ii
        integer, intent(in) :: ie

	kiithis = nen3v(ii,ie)

	end

!***********************************************************

        pure function kiinext(ii,ie)

! gets node at position ii+1 in ie

	integer		    :: kiinext
        integer, intent(in) :: ii
        integer, intent(in) :: ie

	kiinext = nen3v(mod(ii,3)+1,ie)

	end

!***********************************************************

        pure function kiibhnd(ii,ie)

! gets node at position ii-1 in ie

	integer		    :: kiibhnd
        integer, intent(in) :: ii
        integer, intent(in) :: ie

	kiibhnd = nen3v(mod(ii+1,3)+1,ie)

	end

!***********************************************************

        pure function iikthis(k,ie)

! gets position of node k in ie

	integer		    :: iikthis
        integer, intent(in) :: k
        integer, intent(in) :: ie

	integer ii

	iikthis = 0

        do ii=1,3
          if( nen3v(ii,ie) .eq. k ) then
            iikthis = ii
            return
          end if
        end do

	end

!***********************************************************

        pure function iiknext(k,ie)

! gets next position of node k in ie

	integer		    :: iiknext
        integer, intent(in) :: k
        integer, intent(in) :: ie

	integer ii,n

	iiknext = 0
	n = basin_get_vertex_of_element(ie)

        do ii=1,n
          if( nen3v(ii,ie) .eq. k ) then
            iiknext = mod(ii,n)+1
            return
          end if
        end do

	end

!***********************************************************

        pure function iikbhnd(k,ie)

! gets back position of node k in ie

	integer		    :: iikbhnd
        integer, intent(in) :: k
        integer, intent(in) :: ie

	integer ii,n

	iikbhnd = 0
	n = basin_get_vertex_of_element(ie)

        do ii=1,n
          if( nen3v(ii,ie) .eq. k ) then
            iikbhnd = mod(ii-2+n,n)+1
            return
          end if
        end do

	end

!***********************************************************

        pure function kknext(k,ie)

! gets node after node k in ie

	integer		    :: kknext
        integer, intent(in) :: k
        integer, intent(in) :: ie

	integer ii

	kknext = 0
	ii = iiknext(k,ie)
	if( ii /= 0 ) kknext = nen3v(ii,ie)

	end

!***********************************************************

        pure function kkbhnd(k,ie)

! gets node before node k in ie

	integer		    :: kkbhnd
        integer, intent(in) :: k
        integer, intent(in) :: ie

	integer ii

	kkbhnd = 0
	ii = iikbhnd(k,ie)
	if( ii /= 0 ) kkbhnd = nen3v(ii,ie)

	end

!==================================================================
        end module basin
!==================================================================

        subroutine basin_check(text)

        use basin

        implicit none

        character*(*), optional :: text

        integer ie,k,ii
        character*80 string

        string = ' '
        if( present(text) ) string = text

        write(6,*) 'checking basin data: ',trim(string)
        write(6,*) nkn,nel,ngr,mbw

        do ie=1,nel
          do ii=1,3
            k = nen3v(ii,ie)
            if( k .le. 0 .or. k .gt. nkn ) then
              write(6,*) ii,ie,k
              write(6,*) 'error checking basin: ',trim(string)
              stop 'error stop basin_check: nen3v'
            end if
          end do
        end do

        write(6,*) 'basin data is ok...'

        end subroutine basin_check

c***********************************************************
c***********************************************************
c***********************************************************

	subroutine sp13test(nb,nvers)

c tests if file is BAS file
c
c nvers > 0 if file is BAS file

	implicit none

	integer nb	!unit number
	integer nvers	!version found (return) (<=0 if error or no BAS file)

	integer ftype,nversm
	parameter (ftype=789233567,nversm=4)

	integer ntype,nversa

	nvers = 0

	if(nb.le.0) return

c-----------------------------------------------------------
c try new format with ftype information
c-----------------------------------------------------------

	rewind(nb)
	read(nb,err=1,end=1) ntype,nversa
	if( ntype .ne. ftype ) return
	if( nversa .le. 3 .or. nversa .gt. nversm ) nversa = -abs(nversa)

	nvers = nversa
	return

c-----------------------------------------------------------
c try old format without ftype information - nvers must be 3
c-----------------------------------------------------------

    1	continue
	rewind(nb)
	read(nb,err=2,end=2) nversa
	if( nversa .ne. 3 ) nversa = -abs(nversa)

	nvers = nversa
	return

c-----------------------------------------------------------
c definitely no BAS file
c-----------------------------------------------------------

    2	continue
	return
	end

c***********************************************************

	subroutine sp13_get_par(nb,nkn,nel,ngr,mbw)

c unformatted read from lagoon file
c
c iunit		unit number of file to be read

	implicit none

	integer nb
	integer nkn,nel,ngr,mbw

	integer nvers
	character*80 file

	file = ' '
	if( nb > 0 ) inquire(nb,name=file)

	call sp13test(nb,nvers)

	if(nvers.eq.0) goto 99
	if(nvers.lt.0) goto 98

	read(nb) nkn,nel,ngr,mbw

	return
   99	continue
	write(6,*) 'Cannot read bas file on unit :',nb
	if( nb > 0 ) write(6,*) 'file name = ',trim(file)
	stop 'error stop : sp13_get_par'
   98	continue
	write(6,*) 'Cannot read version: nvers = ',-nvers
	if( nb > 0 ) write(6,*) 'file name = ',trim(file)
	stop 'error stop : sp13_get_par'
   97	continue

	end

c***********************************************************

	subroutine sp13rr(nb,nknddi,nelddi)

c unformatted read from lagoon file
c
c iunit		unit number of file to be read

	use basin

	implicit none

	integer nb,nknddi,nelddi

	include 'param.h'

	integer i,ii,nvers

	call sp13test(nb,nvers)

	if(nvers.eq.0) goto 99
	if(nvers.lt.0) goto 98

	read(nb) nkn,nel,ngr,mbw
	read(nb) dcorbas,dirnbas
	read(nb) descrr

	if(nkn.gt.nknddi.or.nel.gt.nelddi) goto 97

	read(nb)((nen3v(ii,i),ii=1,3),i=1,nel)
	read(nb)(ipv(i),i=1,nkn)
	read(nb)(ipev(i),i=1,nel)
	read(nb)(iarv(i),i=1,nel)

	read(nb)(xgv(i),i=1,nkn)
	read(nb)(ygv(i),i=1,nkn)
	read(nb)((hm3v(ii,i),ii=1,3),i=1,nel)

	do i=1,nkn
	  iarnv(i) = 0
	end do

c	call sp13ts(nvers,79,0)

	return
   99	continue
	write(6,*) 'Cannot read bas file on unit :',nb
	stop 'error stop sp13rr: error reading file'
   98	continue
	write(6,*) 'Cannot read version: nvers = ',-nvers
	write(6,*) 'nvers = ',-nvers
	stop 'error stop sp13rr: error in version'
   97	continue
	write(6,*) 'nknddi,nelddi :',nknddi,nelddi
	write(6,*) 'nkn,nel       :',nkn,nel
	write(6,*) 'ngr,mbw       :',ngr,mbw
	stop 'error stop sp13rr: dimension error'
	end

c***********************************************************

	subroutine sp13uw(nb)

c unformatted write to lagoon file
c
c nb		unit number for write

	use basin

	implicit none

	integer nb

	include 'param.h'

	integer i,ii

	integer ftype,nversm
	parameter (ftype=789233567,nversm=4)

	if(nb.le.0) goto 99

	rewind(nb)

	write(nb) ftype,nversm
	write(nb) nkn,nel,ngr,mbw
	write(nb) dcorbas,dirnbas
	write(nb) descrr

	write(nb)((nen3v(ii,i),ii=1,3),i=1,nel)
	write(nb)(ipv(i),i=1,nkn)
	write(nb)(ipev(i),i=1,nel)
	write(nb)(iarv(i),i=1,nel)

	write(nb)(xgv(i),i=1,nkn)
	write(nb)(ygv(i),i=1,nkn)
	write(nb)((hm3v(ii,i),ii=1,3),i=1,nel)

c	call sp13ts(nvers,78,0)

	return
   99	continue
	write(6,*) 'Writing basin...'
	write(6,*) 'Cannot write bas file on unit :',nb
	stop 'error stop : sp13uw'
	end

c*************************************************

	subroutine sp13_set_1d

c sets 1d element structure

	use basin

	implicit none

	integer ie

	nel_tot = nel
	widev = 0.

	do ie=1,nel
	  if( nen3v(3,ie) == 0 ) exit
	end do

	has_1d = .false.
	nel_2d = ie - 1
	if( nel_2d == nel ) return		!everything set

	has_1d = .true.
	if( .not. enable_1d ) then
	  write(6,*) '1d elements found but no support compiled'
	  write(6,*) nel,nel_2d
	  write(6,*) 'please set enable_1d=.true. in module basin'
	  stop 'error stop sp13_set_1d: no support for 1d network'
	end if

	do ie=nel_2d+1,nel
	  if( nen3v(3,ie) /= 0 ) then	!no 2d elements allowed after or in 1d
	    write(6,*) '2d elements found after 1d elements'
	    write(6,*) nel,nel_2d,ie,nen3v(3,ie)
	    stop 'error stop sp13_set_1d: wrong sequence of elements'
	  end if
	  widev(ie) = hm3v(3,ie)
	  hm3v(3,ie) = 0.5 * ( hm3v(1,ie) + hm3v(2,ie) )
	end do

	end

c*************************************************

	subroutine sp13ts(nvers,nb,n)

c test write to unit nb

c writes first n values, if n=0 -> all values

	use basin

	implicit none

	integer nvers,nb,n

	include 'param.h'

	integer i,ii
	integer nkn1,nel1

	nkn1 = min(nkn,n)
	if( nkn1 .le. 0 ) nkn1 = nkn
	nel1 = min(nel,n)
	if( nel1 .le. 0 ) nel1 = nel

	rewind(nb)

	write(nb,*) 'sp13ts:'
	write(nb,*) nvers
	write(nb,*) nkn,nel,ngr,mbw
	write(nb,*) dcorbas,dirnbas
	write(nb,*) descrr

	write(nb,*)((nen3v(ii,i),ii=1,3),i=1,nel1)
	write(nb,*)(ipv(i),i=1,nkn1)
	write(nb,*)(ipev(i),i=1,nel1)
	write(nb,*)(iarv(i),i=1,nel1)

	write(nb,*)(xgv(i),i=1,nkn1)
	write(nb,*)(ygv(i),i=1,nkn1)
	write(nb,*)((hm3v(ii,i),ii=1,3),i=1,nel1)

	return
	end

c*************************************************

	subroutine bas_info

	use basin

	implicit none

	include 'param.h'

        write(6,*)
        write(6,*) trim(descrr)
        write(6,*)
        write(6,*) ' nkn = ',nkn,'  nel = ',nel
        write(6,*) ' mbw = ',mbw,'  ngr = ',ngr
        write(6,*)
        write(6,*) ' dcor = ',dcorbas,'  dirn = ',dirnbas
        write(6,*)

	end

c*************************************************

	subroutine bas_get_geom(dcor,dirn)

	use basin

	implicit none

	include 'param.h'

	real dcor,dirn

	dcor = dcorbas
	dirn = dirnbas

	end

c*************************************************

	subroutine bas_get_para(nkna,nela,ngra,mbwa)

	use basin

	implicit none

	include 'param.h'

	integer nkna,nela,ngra,mbwa

	nkna = nkn
	nela = nel
	ngra = ngr
	mbwa = mbw

	end

c*************************************************

	subroutine bas_get_minmax(xmin,ymin,xmax,ymax)

	use basin

	implicit none

	include 'param.h'

	real xmin,ymin,xmax,ymax

	integer k

	xmin = xgv(1)
	xmax = xgv(1)
	ymin = ygv(1)
	ymax = ygv(1)

	do k=1,nkn
	  xmin = min(xmin,xgv(k))
	  xmax = max(xmax,xgv(k))
	  ymin = min(ymin,ygv(k))
	  ymax = max(ymax,ygv(k))
	end do

	end

c*************************************************

        function is_depth_unique()

	use basin

	implicit none

        logical is_depth_unique

	integer ie,ii,k
	real h
        real :: flag = -999.
        real haux(nkn)

        haux = flag
	is_depth_unique = .false.

        do ie=1,nel
          do ii=1,3
            k = nen3v(ii,ie)
            h = hm3v(ii,ie)
            if( haux(k) == flag ) haux(k) = h
	    if( h /= haux(k) ) return
          end do
        end do

	is_depth_unique = .true.

        end function is_depth_unique

c*************************************************
c*************************************************
c*************************************************

	subroutine bas_insert_regular(regpar)

	use basin

c inserts regular basin (boxes) into basin structure

	implicit none

	real regpar(7)

	logical bdebug
	integer nx,ny,ix,iy
	integer k,ie,nk,ne
	integer k1,k2,k3,k4,km
	real x0,y0,dx,dy
	integer, allocatable :: indexv(:,:)
	integer, allocatable :: indexm(:,:)

        nx = nint(regpar(1))
        ny = nint(regpar(2))
        x0 = regpar(3)
        y0 = regpar(4)
        dx = regpar(5)
        dy = regpar(6)

	nk = nx*ny + (nx-1)*(ny-1)
	ne = 4*(nx-1)*(ny-1)

	allocate(indexv(nx,ny))
	allocate(indexm(nx,ny))

	call basin_init(nk,ne)

	mbw = 0
	descrr = 'regular generated grid'
	iarv = 0
	iarnv = 0
	hm3v = 0.

	k = 0
        do iy=1,ny
          do ix=1,nx
	    k = k + 1
	    ipv(k) = k
	    indexv(ix,iy) = k
	    xgv(k) = x0 + (ix-1)*dx
	    ygv(k) = y0 + (iy-1)*dy
          end do
        end do

        do iy=2,ny
          do ix=2,nx
	    k = k + 1
	    ipv(k) = k
	    indexm(ix,iy) = k
	    xgv(k) = x0 + (ix-1.5)*dx
	    ygv(k) = y0 + (iy-1.5)*dy
          end do
        end do

	ie = 0
        do iy=2,ny
          do ix=2,nx
	    k1 = indexv(ix-1,iy-1)
	    k2 = indexv(ix,iy-1)
	    k3 = indexv(ix,iy)
	    k4 = indexv(ix-1,iy)
	    km = indexm(ix,iy)
	    ie = ie + 1
	    ipev(ie) = ie
	    nen3v(1,ie) = km
	    nen3v(2,ie) = k1
	    nen3v(3,ie) = k2
	    ie = ie + 1
	    ipev(ie) = ie
	    nen3v(1,ie) = km
	    nen3v(2,ie) = k2
	    nen3v(3,ie) = k3
	    ie = ie + 1
	    ipev(ie) = ie
	    nen3v(1,ie) = km
	    nen3v(2,ie) = k3
	    nen3v(3,ie) = k4
	    ie = ie + 1
	    ipev(ie) = ie
	    nen3v(1,ie) = km
	    nen3v(2,ie) = k4
	    nen3v(3,ie) = k1
          end do
        end do

        call estimate_ngr(ngr)

	deallocate(indexv)
	deallocate(indexm)

	bdebug = .true.
	if( bdebug ) then
	  write(6,*) 'regular basin inserted: ',nk,ne
	  write(6,*) nx,ny,x0,y0,dx,dy
	  write(6,*) minval(xgv),maxval(xgv)
	  write(6,*) minval(ygv),maxval(ygv)
	end if

	end

c*************************************************
c*************************************************
c*************************************************

        subroutine estimate_ngr(ngrade)

c estimates grade of basin - estimate is exact

	use basin

        implicit none

	integer ngrade

        integer ng(nkn)

	call compute_ng(ngrade,ng)

	end

c*************************************************

        subroutine compute_ng(ngrade,ng)

c computes grade of basin and nuber of grades per node

	use basin

        implicit none

	integer ngrade
        integer ng(nkn)

        integer ii,ie,k
	integer k1,k2,n
	integer, allocatable :: ngv(:,:)

	ng = 0

        do ie=1,nel
          do ii=1,3
            k = nen3v(ii,ie)
            ng(k) = ng(k) + 1
          end do
        end do

	ngrade = maxval(ng) + 1			!first guess

	allocate(ngv(0:2*ngrade,nkn))
	ngv = 0

        do ie=1,nel
          do ii=1,3
            k1 = nen3v(ii,ie)
            k2 = nen3v(mod(ii,3)+1,ie)
	    call ng_insert(k1,k2,ngrade,nkn,ngv)
	    call ng_insert(k2,k1,ngrade,nkn,ngv)
	  end do
	end do

	do k=1,nkn
	  n = ngv(0,k)
	  if( n == 0 ) then			!inner node
	    !nothing to do
	  else if( n == 2 ) then		!boundary node
	    ng(k) = ng(k) + 1
	  else
	    write(6,*) 'wrong connectivity: ',k,n
	    stop 'error stop estimate_ngr: internal error'
	  end if
	end do

	deallocate(ngv)

	ngrade = maxval(ng)

        end

c*************************************************

	subroutine ng_insert(k1,k2,ng,nkn,ngv)

	implicit none

	integer k1,k2
	integer ng,nkn
	integer ngv(0:2*ng,nkn)

	integer i,n

	n = ngv(0,k1)

	do i=1,n
	  if( ngv(i,k1) == k2 ) then
	    ngv(i,k1) = ngv(n,k1)
	    ngv(0,k1) = ngv(0,k1) - 1
	    return
	  end if
	end do

	n = n + 1
	ngv(0,k1) = n
	ngv(n,k1) = k2

        end

c*************************************************

