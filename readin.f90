

 subroutine readin(itype)
	use SOLVERLIB
    use ds_hyjump
    use ExcaDS
	use dflib
	implicit none
	integer:: itype,unit,i,j,k
	LOGICAL(4)::tof
	character(1024) term,keyword
	character(1024)::nme
	CHARACTER(3)        drive
	CHARACTER(1024)      dir
	CHARACTER(1024)      name
	CHARACTER(1024)      ext
	type(qwinfo) winfo
	integer(4)::length,msg
	type(bc_tydef),allocatable::bf1(:),bf2(:)
    EXTERNAL::SetLineColor,Marker,LineStyle,SETBGCOLOR
    
	term="Text Files(*.sinp),*.sinp; &
			  Data Files(*.dat),*.dat; &
			  Prof.Cao Program files(*.z7),*.z7; &
			  All Files(*.*),*.*;"
	term=trim(term)
	call setmessageqq(term,QWIN$MSG_FILEOPENDLG)
	winfo%TYPE = QWIN$MAX
	tof=SETWSIZEQQ(QWIN$FRAMEWINDOW, winfo)
	tof=SETWSIZEQQ(0, winfo)  
	term=' '
	title=''
	open(1,file=' ',status='old' )
	unit=1
	print *, 'Begin to read in data...'
	call read_execute(unit,itype,keyword)

	if(itype==0) then
		inquire(1,name=nme)
		length = SPLITPATHQQ(nme, drive, dir, name, ext)
		resultfile=trim(drive)//trim(dir)//trim(name)//'_datapoint.dat'
		IF(solver_control.solver==LPSOLVER) THEN
			resultfile1=trim(drive)//trim(dir)//trim(name)//'_lpsolve.lp'
		END IF
		IF(solver_control.solver==MOSEK) THEN
			resultfile1=trim(drive)//trim(dir)//trim(name)//'_mosek.lp'
		END IF
		resultfile2=trim(drive)//trim(dir)//trim(name)//'_tec.plot'
		resultfile21=trim(drive)//trim(dir)//trim(name)//'_barfamilydiagram_tec.plot'
		resultfile22=trim(drive)//trim(dir)//trim(name)//'_barfamilydiagram_res.dat'
		resultfile3=trim(drive)//trim(dir)//trim(name)//'_msg.dat'
        hydraulicjumpfile=trim(drive)//trim(dir)//trim(name)//'_hjump.dat'
		EXCAMSGFILE=trim(drive)//trim(dir)//trim(name)//'_exca_msg.dat'
		EXCAB_BEAMRES_FILE=trim(drive)//trim(dir)//trim(name)//'_exca_res.dat'
		EXCAB_STRURES_FILE=trim(drive)//trim(dir)//trim(name)//'_exca_stru.dat'
	end if
	open(99,file=resultfile3,status='replace')
	!the default value of Title=resultfile2.
	msg=len_trim(title)
	if(len_trim(title)==0) title=resultfile2

	close(1)
	print * ,'Read in data completed!' 

    
    
    
	!INITIALIZATION 
    
    IF(ISEXCA2D/=0) THEN
        CALL GenElement_EXCA2()
        solver_control.bfgm=continuum
        !CHECKDATA
        DO I=1,NSOILPROFILE
		    do j=1,soilprofile(i).nasoil
			    IF(KPOINT(NDIMENSION,soilprofile(i).asoil(j).z(1))<KPOINT(NDIMENSION,soilprofile(i).asoil(j).z(2))) THEN
                    PRINT *, "Z1 IS SMALLER THAN Z2.PLEASE CKECK. SOILPROFILE=, ACTIVE SIDE SOILLAYER=",I,J
                    STOP
                ENDIF
		    enddo
		    do j=1,soilprofile(i).npsoil
               IF(KPOINT(NDIMENSION,soilprofile(i).Psoil(j).z(1))<KPOINT(NDIMENSION,soilprofile(i).Psoil(j).z(2))) THEN
                    PRINT *, "Z1 IS SMALLER THAN Z2.PLEASE CHECK. SOILPROFILE=, PASSIVE SIDE SOILLAYER=",I,J
                    STOP
                ENDIF
            enddo 
            
        ENDDO
        msg=INSERTMENUQQ (5, 0, $MENUENABLED, 'GraphSetting'c,NUL)
		msg=INSERTMENUQQ (5, 1, $MENUENABLED, 'Gray'c, SetLineColor)
		msg=INSERTMENUQQ (5, 2, $MENUENABLED, 'NoMarker'c, Marker)
		msg=INSERTMENUQQ (5, 3, $MENUENABLED, 'ThickLine'c, LineStyle)
        msg=INSERTMENUQQ (5, 4, $MENUENABLED, 'BGC_BLACK'c, SETBGCOLOR)
        !solver_control.ismkl=NO
    ENDIF    
    
    
	LF1D(0,1)=0.0D0
	LF1D(0,2)=1.0D0	
	if(nsf==0) then
		nsf=1
		nstep=max(1,nstep)
		allocate(sf(0:nsf))		
		allocate(sf(1).factor(0:nstep),sf(0).factor(0:nstep))
		sf(0).factor(0)=0.0d0
		sf(0).factor(1:nstep)=1.0d0
		sf(1).factor(1:nstep)=1.0d0
		sf(1).factor(0)=0.0d0
	end if
	
	if(.not.allocated(timestep)) then
		allocate(timestep(0:nstep))
		timestep(0:nstep).nsubts=1
		do i=0,nstep
			allocate(timestep(i).subts(1)) 
			timestep(i).subts(1)=1.d0  !如为稳态分析，则此时间步长为虚步长。
		end do        
    end if
    
	if(.not.allocated(stepinfo)) then
		allocate(stepinfo(0:nstep))
        nstepinfo=nstep
        stepinfo(0).matherstep=0
        stepinfo(0).issteady=.true.
        do i=1,nstepinfo
            stepinfo(i).matherstep=i-1
            stepinfo(i).issteady=.true.
        end do
    end if
    
    
    if(nhjump/=0) open(unit_hj,file=hydraulicjumpfile,status='replace')
    if(HJump_CP==1) then
        do i=1,nstep
			do j=1,timestep(i).nsubts
				do k=1,nhjump
					call HJ_WaterSurfaceProfile_RC(k,i,j)
				end do
			end do
        end do
        stop "WaterSurfaceProfile Calculation Completed!"
	else
		do j=1,nhjump
			allocate(bf1(bd_num+hjump(j).nnode))
			do i=bd_num+1,bd_num+hjump(j).nnode
				bf1(i).node=hjump(j).node(i-bd_num)
				hjump(j).bc_node(i-bd_num)=i
				bf1(i).dof=4
				!bf1(i).value=ar(3)
				
				bf1(i).sf=0								

				bf1(i).isdual=1

			end do
			if(bd_num>0) then
				bf1(1:bd_num)=bc_disp(1:bd_num)
				deallocate(bc_disp)
			end if			
			allocate(bc_disp(bd_num+hjump(j).nnode))
			bc_disp=bf1
			bd_num=bd_num+hjump(j).nnode
			
			deallocate(bf1)	
						
			!deallocate(bf1)
		end do
    end if
    
	if(ncoord==0) then
		allocate(coordinate(0:0))
		coordinate(0).c=0.0
		coordinate(0).c(1,1)=1.0
		coordinate(0).c(2,2)=1.0
		coordinate(0).c(3,3)=1.0
	end if
	if(nueset==1) then
		ueset(0).enum=enum
		ueset(0).name='all'
		allocate(ueset(0).element(ueset(0).enum))
		do i=1,ueset(0).enum
			ueset(0).element(i)=i
		end do
	end if
	if(nunset==1) then
		unset(0).nnum=nnum
		unset(0).name='all'
		allocate(unset(0).node(unset(0).nnum))
		do i=1,unset(0).nnum
			unset(0).node(i)=i
		end do
	end if
	
	!!!以水头为未知量的渗流模型，水头不具有叠加性，导致其多步求解时与以位移为未知量的其它模型不同，必须注意。
    !!!假定，如果为渗流模型，则模型中所有的单元均为渗流单元。
	if(solver_control.type/=spg.and.(element(1).ec==spg2d.or.element(1).ec==spg.or.element(1).ec==cax_spg)) then
		solver_control.type=spg
	end if
	
	do i=1, bd_num
		if(bc_disp(i).isdual>0) then
			do j=1,numNseep
				if((Nseep(j).node==bc_disp(i).node).and.(Nseep(j).dof==bc_disp(i).dof)) then
					bc_disp(i).isdual=j
					Nseep(j).isdual=i
					exit
				end if
			end do
			if(j>numNseep) bc_disp(i).isdual=0
		end if
	end do
	
	!intialize 
	do i=1,nSMNP
		do j=1,bd_num
			if(bc_disp(j).node==smnp(i).master.and.bc_disp(j).dof==smnp(i).mdof) then
				print *, "displacement condition is applied on the master node=",	i
				stop
			end if
		end do
		do j=1,bl_num
			if(bc_load(j).node==smnp(i).master.and.bc_load(j).dof==smnp(i).mdof) then
				smnp(i).nmbl=smnp(i).nmbl+1
				if(smnp(i).nmbl>10) stop "smnp(i).nmbl>10.作用在master节点mdof度的荷载个数最多10."
				smnp(i).mbl(smnp(i).nmbl)=j
			end if
		end do
    end do
	
    if(nfreedof>0) then
		call enlarge_node(node,nnum,nfreedof,k)
        do i=1,nfreedof
           do j=1,element(freedof(i).element).nnum
                if(element(freedof(i).element).node(j)==freedof(i).node) then
                    element(freedof(i).element).ifreedof=i
                    freedof(i).newnode=k
                    element(freedof(i).element).node(j)=k
                    node(k)=node(freedof(i).node)                    
                    k=k+1
                    exit
                endif                
           enddo                       
        enddo    
        
	endif

	
	!if(solver_control.bfgm==lacy) then
	!	do i=1,bd_num
	!		if(bc_disp(i).dof==4) then
	!			!convert the hydraulic head boundaries to pressure head boundaries.
	!			bc_disp(i).value=bc_disp(i).value-node(bc_disp(i).node).coord(ndimension)
	!		end if
	!	end do
	!end if	
	return

 end subroutine



subroutine read_execute(unit,itype,keyword)

!**************************************************************************************************************
!IF ITYPE=0, READ IN DATAS  from THE UNIT FILE TO ITS END.
!IF ITYPE>0, JUST READ IN DATA RELATED WITH THE KEYWORD BLOCK IN THE UNIT FILE
!INPUT VARIABLES:
!UNIT: FILE NUMBER, 
!ITYPE: DEFAULT VALUE=0, IF VALUE>0, IT WILL WORK WITH THE KEYWORD.  
!KEYWORD: DATA BLOCK KEYWORD
!A LINE STARTED WITH '/' IS A COMMENT LINE, IT WILL BE SKIPPED DURING READING
!OUPUT VARIABLES:
!NO EXPLICIT OUTPUT VARIABLES. ALL THE READ IN DATA STORED IN THE VARIABLES DEFINED IN THE MODULE SOLVERDS
!SUBROUTINES CALLED: 
!COMMAND()
!Programer: LUO Guanyong
!Last update: 2008.03.16
!**************************************************************************************************************
	use solverds
	implicit none
	integer::unit,ef,ITYPE,iterm,i,strL,N1
	parameter(iterm=1024)
	character(iterm)::term,keyword,term2
	character(1)::ch
	
	ef=0
	
	do while(ef==0)
		
		term=''
		do while(.true.)
			read(unit,999,iostat=ef) term2
			if(ef<0) exit	
			term2=adjustL(term2)
			strL=len_trim(term2)
			if(strL==0.or.term2(1:1)=='/'.or.term2(1:1)=='#') cycle		

			!每行后面以'/'开始的后面的字符是无效的。
			if(index(term2,'/')/=0) then
				strL=index(term2,'/')-1
				term2=term2(1:strL)
				strL=len_trim(term2)
			end if			

			if(term2(strL:strL)/="&") then
				term=trim(adjustL(term))//trim(term2)
				exit
			else
				term=trim(adjustL(term))//term2(1:strL-1)			
			end if
		end do
		
		if(ef<0) exit
		
		term=adjustl(term)
		strL=len_trim(term)
		if(strL==0) cycle
		do i=1,strL !remove 'Tab'
			if(term(i:i)/=char(9)) exit
		end do
		term=term(i:strL)
		term=adjustl(term)
		strL=len_trim(term)
		if(strL==0) cycle		
		write(ch,'(a1)') term
		if(ch/='/'.and.ch/='#') then
			!backspace(unit)
			!read(unit,999) term
			call lowcase(term,iterm)
			call translatetoproperty(term)			
			term=adjustl(trim(term))
			call solvercommand(term,unit)			 	
		end if
	end do


	
999	format(a<iterm>)

end subroutine


subroutine solvercommand(term,unit)

!**************************************************************************************************************
!Function:
!read in data block: "term" from the unit file.
!Input Variables:
!Term: data block keyword
!Unit: data file unit number
!Output varibibles:
!No explicit output variable. All the data read in is stored in variables defined in modulus SOLVERDS.
!Modulus Used:
!dflib, SOLVERDS
!Subroutines Called:
!strtoint()
!Programer: LUO Guanyong
!Last Update: 2008.03.16
!**************************************************************************************************************
	use dflib
	use solverlib
	use ExcaDSLIB
    use ds_hyjump
	implicit none
    
	integer::unit
	character(1024) term
	integer::i,j,k
	integer::n1,n2,n3,n4,n5,n_toread,nmax
	real(8)::ar(MaxNumRead)=0,t1
	integer(4)::msg
	type(mat_tydef),allocatable::mat1(:)
	type(element_tydef),allocatable::element1(:),element2(:)
	type(bc_tydef),allocatable::bf1(:),bf2(:)
	integer::enum1=0,nnum1=0,et1=0,set1=0,material1=0,&
		ndof1=0,nd1=0,ngp1=0,matid1=0,nset=0,sf1=0,system1=0,nbf1=0
	integer::ec1=0,id1=0
	character(16)::stype
	character(128)::cstring
	character(64)::name1,set(50)
	logical::isset=.false.,TOF1=.FALSE.
	
	type(bc_tydef),allocatable::Nseep1(:)

    INTERFACE
        SUBROUTINE SKIPCOMMENT(BARFAMILY_RES,EF)
            INTEGER,INTENT(IN)::BARFAMILY_RES
            INTEGER,OPTIONAL::EF
        END SUBROUTINE
    END INTERFACE   
    
	nmax=MaxNumRead
	n_toread=MaxNumRead
	ar=0.0
	set=''

	term=trim(term)

	select case(term)
		case('title')
			print *, 'Reading TITLE data...'
			call skipcomment(unit)
			read(unit,'(a1024)') title
		case('node')
			print *, 'Reading NODE data...'
			do i=1, pro_num
				select case(property(i).name)
					case('num')
						nnum=int(property(i).value)
					case('datapacking','dp')
						datapacking=int(property(i).value)
					case('dimension','d')
						ndimension=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(node(nnum))
			if (datapacking==1) then
				call skipcomment(unit)
				read(unit,*) ((node(i).coord(j),j=1,ndimension),i=1,nnum)
			else
				call skipcomment(unit)
				read(unit,*) ((node(i).coord(j),i=1,nnum),j=1,ndimension)
			end if
		case('kpoint','kp')
			print *, 'Reading KEYPOINT data...'
			do i=1, pro_num
				select case(property(i).name)
					case('num')
						nkp=int(property(i).value)
					!case('datapacking','dp')
					!	datapacking=int(property(i).value)
					!case('dimension','d')
					!	ndimension=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(KPOINT(1:NDIMENSION+1,nkp),kpnode(nkp))
            KPOINT(NDIMENSION+1,:)=DEFAULTSIZE
            
			do i=1,nkp
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				!read(unit,*) n1,kpoint(1:ndimension,n1)
                kpoint(1:ndimension,int(ar(1)))=ar(2:ndimension+1)
                if(n1>ndimension+1) kpoint(ndimension+1,int(ar(1)))=ar(ndimension+2)                
            end do
            TOF1=.FALSE.
			do i=1,nkp-1
                DO J=I+1,NKP
                    T1=0.D0
                    DO K=1,NDIMENSION
                        T1=T1+(KPOINT(K,J)-KPOINT(K,I))**2
                    ENDDO
                    IF(ABS(T1)<1E-7) THEN
                        PRINT *, "THE POINTS OF I AND J ARE IDENTICAL. I,J=",I,J
                        TOF1=.TRUE.
                    ENDIF
                ENDDO
            end do            
            IF(TOF1) STOP "ERROR STOP IN KPOINT READ IN."
		case('hbeam','pile') !for retaining structure
			print *, 'Reading beam/pile(Retaining Structure) data...'
			do i=1, pro_num
				select case(property(i).name)
					case('num')
						npile=int(property(i).value)
					!case('datapacking','dp')
					!	datapacking=int(property(i).value)
					!case('dimension','d')
					!	ndimension=int(property(i).value)
					case('isplot')
						ishbeam=int(property(i).value)
						isExca2D=2
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(pile(npile))
			do i=1,npile				
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				pile(i).nseg=int(ar(1))
				if(n1>1) pile(i).system=int(ar(2))
				allocate(pile(i).kpoint(pile(i).nseg+1),pile(i).mat(pile(i).nseg))
				call skipcomment(unit)
				read(unit,*) pile(i).kpoint
				call skipcomment(unit)
				read(unit,*) pile(i).mat
			end do			
		case('strut') !for retaining structure
			print *, 'Reading STRUT(Retaining Structure) data...'
			n2=0
			n3=0
			n4=0
            do i=1, pro_num
				select case(property(i).name)
					case('num')
						n3=int(property(i).value)
					case('isbar')
						n2=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			call enlarge_strut(strut,nstrut,n3,n4)
			!allocate(strut(nstrut))
			
			do i=1,n3
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				if(n2==0) then
					strut(n4-1+i).z(1)=int(ar(1))
					strut(n4-1+i).mat=int(ar(2))
					strut(n4-1+i).sf=int(ar(3))
					!if(n1>3) strut(n4-1+i).preLoad=int(ar(4))
					!if(n1>4) strut(n4-1+i).preDis=int(ar(5))
				else
					strut(n4-1+i).z(1)=int(ar(1))
					strut(n4-1+i).z(2)=int(ar(2))
					strut(n4-1+i).mat=int(ar(3))
					strut(n4-1+i).sf=int(ar(4))
					!if(n1>4) strut(n4-1+i).preLoad=int(ar(5))
					!if(n1>5) strut(n4-1+i).preDis=int(ar(6))				
				endif
				
				strut(n4-1+i).isbar=n2
				
			end do				

		case('action') !for retaining structure
			print *, 'Reading ACTION(Retaining Structure) data...'
			do i=1, pro_num
				select case(property(i).name)
					case('num')
						naction=int(property(i).value)
					!case('datapacking','dp')
					!	datapacking=int(property(i).value)
					!case('dimension','d')
					!	ndimension=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(action(naction))
			do i=1,naction
				call skipcomment(unit)
				read(unit,'(A64)') action(i).title
				n2=0
				n3=0
				n4=0
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				action(i).nkp=int(ar(1))
				action(i).type=int(ar(2))
				action(i).dof=int(ar(3))
				action(i).ndim=int(ar(4))
				if(n1>4) action(i).sf=int(ar(5))
				if(n1>5) n3=int(ar(6))
				if(n1>6) n4=int(ar(7))
				allocate(action(i).kpoint(action(i).nkp),action(i).value(action(i).nkp), &
						 action(i).vsf(action(i).nkp),action(i).exvalue(action(i).nkp,2),&
						 action(i).node(action(i).nkp))
				call skipcomment(unit)
				read(unit,*) action(i).kpoint
				call skipcomment(unit)
				read(unit,*) action(i).value
				if(n3==1) then
					call skipcomment(unit)
					read(unit,*) action(i).vsf
				else
					action(i).vsf=0
				endif
				if(n4==1) then
					call skipcomment(unit)
					read(unit,*) action(i).exvalue
				else
					action(i).exvalue(:,1)=-1E20
					action(i).exvalue(:,2)=1E20
				endif				
				
			end do
			
			
		case('element')
			print *, 'Reading ELEMENT data...'
			matid1=0
            system1=0
			name1=""
			sf1=0
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						enum1=int(property(i).value)
					case('set')
						set1=int(property(i).value)
						isset=.true.
					case('et','type')
						et1=int(property(i).value)
!						if(et1>maxet) maxet=et1
!						if(et1<minet) minet=et1
						!according to the element type, return the element node number,and the dofs number
						call ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,ec1)
					case('material','mat')
						material1=int(property(i).value)
					case('matid','material id')
						matid1=int(property(i).value)
					case('system') !local coordinate
						system1=int(property(i).value)
					case('title','name')
						name1=property(i).cvalue
					CASE('sf','step function')
						sf1=int(property(i).value)
					case default
						call Err_msg(property(i).name)						
				end select
			end do
			
			if(matid1==0) matid1=material1 !If there is only one set of such material of this type in this model 
			if(isset) then
				isset=.false.
			else
				set1=set1+1
			end if
			allocate(element1(enum1))
			do i=1,enum1
				element1(i).nnum=nnum1
				allocate(element1(i).node(nnum1))
				select case(et1)
					!case(beam) !beam element, a local system must be input.
					!	call skipcomment(unit)
					!	read(unit,*) element1(i).node,element1(i).system
					case(dkt3,shell3,shell3_KJB) !.h  is the thickness of the element.
						call skipcomment(unit)
						read(unit,*) element1(i).node,element1(i).PROPERTY(3)
					case default
						call skipcomment(unit)
						read(unit,*) element1(i).node
				end select
				element1(i).id=i
				element1(i).et=et1
				element1(i).set=set1
				element1(i).mat=matid1
				element1(i).mattype=material1
				element1(i).ndof=ndof1
				element1(i).ngp=ngp1
				element1(i).nd=nd1
				element1(i).ec=ec1
				element1(i).sf=sf1
				if(et1==beam) element1(i).system=system1
			end do
			neset=neset+1
			eset(neset).num=set1
			eset(neset).stype=stype
			eset(neset).grouptitle=name1
			eset(neset).et=et1
			eset(neset).ec=ec1
            eset(neset).system=system1
			eset(neset).enums=enum+1
			allocate(element2(enum+enum1))
			element2(1:enum)=element(1:enum)
			element2(enum+1:enum+enum1)=element1(1:enum1)
			if(allocated(element))	deallocate(element)
			deallocate(element1)
			enum=enum+enum1
			eset(neset).enume=enum
			allocate(element(enum))
			element=element2
			deallocate(element2)
        case('rcd')
            print *, 'Reading Rigid Connected Dof data...'
            do i=1,pro_num
				select case(property(i).name)
					case('num')
						enum1=int(property(i).value)
					case('dof')
						material1=int(property(i).value)
					case default
						call Err_msg(property(i).name)						
				end select
			end do
		case('material')
			print *, 'Reading MATERIAL data...'
			n1=0
			matid1=0
			j=0
			name1=""
            n3=0
			do i=1,pro_num
				select case(property(i).name)
					case('type')
						j=int(property(i).value)
						!material(j).id=j
					case('isff')					
						if(int(property(i).value)==YES)  n1=1
					case('matid')
						matid1=int(property(i).value)
					case('issf')
						n3=int(property(i).value)
					case('name','title')
						name1=property(i).cvalue
					case default
						call Err_msg(property(i).name)
				end select
			end do
			
			if(matid1==0) matid1=j !If there is only one set of such material of this type in this model 
			
			material(matid1).type=j
			material(matid1).name=name1
			if(n1==1) material(matid1).isff=.true.
			call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
			!n1=size(material(matid1).property)
			material(matid1).property(1:n1)=ar(1:n1)	
			select case(material(matid1).type)
				case(mises)
					material(matid1).weight=material(matid1).property(4)
				case(mc)
					material(matid1).weight=material(matid1).property(6)
				case(eip_bar)
					if(n1<=4) then
						material(matid1).property(5)=-1.0D20 !最大轴向压力
						material(matid1).property(6)=1.0D20	 !最大的轴向拉力
					end if
			end select
			
			if(material(matid1).isff) then
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				material(matid1).ff1d(1:n1)=int(ar(1:n1))
			end if
			
			if(n3==1) then
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				material(matid1).sf(1:n1)=int(ar(1:n1))
			else
				material(matid1).sf=0
			end if
			
		case('load')
			print *,'Reading LOAD data...'
			n2=0
			n3=0
			n4=0
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nbf1=int(property(i).value)
					case('ssp_onepile')
						n2=int(property(i).value)
					case('spg_isdual')
						n3=int(property(i).value)
					case('sf','stepfunction','stepfunc')
						n4=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(bf1(bl_num+nbf1))
			do i=bl_num+1,bl_num+nbf1
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				bf1(i).node=int(ar(1))
				bf1(i).dof=int(ar(2))
				bf1(i).value=ar(3)
				
				bf1(i).sf=n4								
				if(n1>=4) bf1(i).sf=int(ar(4))
				bf1(i).isdual=n3
				if(n1>=5) bf1(i).isdual=int(ar(5)) !同是也可能是出溢边界
				bf1(i).ssp_onepile=n2
				if(n1>=6) bf1(i).ssp_onepile=int(ar(6))

			end do
			if(bl_num>0) then
				bf1(1:bl_num)=bc_load(1:bl_num)
				deallocate(bc_load)
			end if			
			allocate(bc_load(bl_num+nbf1))
			bc_load=bf1
			bl_num=bl_num+nbf1
			deallocate(bf1)
		case('ncf','normal contact force')
			print *,'Reading normal contact force data...'
			n2=0
			n3=0
			n4=0
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nbf1=int(property(i).value)
					case('ssp_onepile')
						n2=int(property(i).value)
					case('spg_isdual')
						n3=int(property(i).value)
					case('sf','stepfunction','stepfunc')
						n4=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(bf1(ncfn+nbf1))
			do i=ncfn+1,ncfn+nbf1
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				bf1(i).node=int(ar(1))
				bf1(i).dof=int(ar(2))
				bf1(i).value=ar(3)
				
				bf1(i).sf=n4								
				if(n1>=4) bf1(i).sf=int(ar(4))
				bf1(i).isdual=n3
				if(n1>=5) bf1(i).isdual=int(ar(5)) !同是也可能是出溢边界
				bf1(i).ssp_onepile=n2
				if(n1>=6) bf1(i).ssp_onepile=int(ar(6))

			end do
			if(ncfn>0) then
				bf1(1:ncfn)=cfn(1:ncfn)
				deallocate(cfn)
			end if			
			allocate(cfn(ncfn+nbf1))
			cfn=bf1
			ncfn=ncfn+nbf1
			deallocate(bf1)	
			
		case('bf','body force','pressure','elt_load')
			print *, 'Reading BODY FORCE data...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nbf1=int(property(i).value)					
					case default
						call Err_msg(property(i).name)
				end select
			end do			
			allocate(bf1(nbf1))
			bf1.value=0.0			
			n1=0
			n2=0			
			do while(n2<nbf1)
				!the structure for each data line must be kept the same.
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				do i=n2+1,n2+n1-3
					bf1(i).node=int(ar(i-n2))
					bf1(i).dof=int(ar(n1-2))
					bf1(i).value=bf1(i).value+ar(n1-1) 
					!Attention. the unit is force/volume if the element is an planar element, then unit should 
					!be Force/volume*(element thickness).
					bf1(i).sf=int(ar(n1))
				end do
				n2=n2+n1-3
				do i=1,nset
					do j=0,nueset
						if(index(ueset(j).name,set(i))>0)  exit
					end do
					if(j==nueset+1) then
						print *, 'No such element set. '//trim(set(i))
						stop
					end if
					bf1(n2+1:n2+ueset(j).enum).node= &
							ueset(j).element(1:ueset(j).enum)
					bf1(n2+1:n2+ueset(j).enum).dof=int(ar(n1-2))					
					bf1(n2+1:n2+ueset(j).enum).value= & 
					bf1(n2+1:n2+ueset(j).enum).value+ar(n1-1)
					bf1(n2+1:n2+ueset(j).enum).sf=int(ar(n1))
					n2=n2+ueset(j).enum						
				end do
								
			end do			
			if(bfnum>0) then
				allocate(bf2(bfnum))
				bf2(1:bfnum)=bf(1:bfnum)
				deallocate(bf)
			end if			
			allocate(bf(bfnum+nbf1))
			if(bfnum>0) bf(1:bfnum)=bf2(1:bfnum)
			bf(bfnum+1:bfnum+nbf1)=bf1
			bfnum=bfnum+nbf1
			deallocate(bf1)
			if(allocated(bf2)) deallocate(bf2)
		case('bc','boundary condition')
			print *,'Reading BOUNDARY CONDITION data...'
			n2=0
			n3=0
			n4=0
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nbf1=int(property(i).value)
					case('ssp_onepile')
						n2=int(property(i).value)
					case('spg_isdual')
						n3=int(property(i).value)
					case('sf','stepfunction','stepfunc')
						n4=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(bf1(bd_num+nbf1))
			do i=bd_num+1,bd_num+nbf1
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				bf1(i).node=int(ar(1))
				bf1(i).dof=int(ar(2))
				bf1(i).value=ar(3)
				
				bf1(i).sf=n4								
				if(n1>=4) bf1(i).sf=int(ar(4))
				bf1(i).isdual=n3
				if(n1>=5) bf1(i).isdual=int(ar(5)) !同是也可能是出溢边界
				bf1(i).ssp_onepile=n2
				if(n1>=6) bf1(i).ssp_onepile=int(ar(6))

			end do
			if(bd_num>0) then
				bf1(1:bd_num)=bc_disp(1:bd_num)
				deallocate(bc_disp)
			end if			
			allocate(bc_disp(bd_num+nbf1))
			bc_disp=bf1
			bd_num=bd_num+nbf1
			deallocate(bf1)	
			
        case('hinge','freedof')
            print *, 'Reading HINGE/FREEDOF data...'
  			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nfreedof=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
            end do 
            allocate(freedof(nfreedof))
            do i=1,nfreedof
                call skipcomment(unit)
				read(unit,*) freedof(i).element,freedof(i).node,freedof(i).dof
            enddo
		case('seepage face')
			print *,'Reading Nodes In SEEPAGEFACE data...'
			n3=0
			n4=0
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						n4=int(property(i).value)
					case('step function','sf')
						n3=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(Nseep1(n4+Numnseep))
			n2=0
			do while(n2<n4)
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				Nseep1(n2+1:n2+n1).node=int(ar(1:n1))
				Nseep1(n2+1:n2+n1).sf=n3
				n2=n1+n2				
			end do
			if(Numnseep>0)	then
				Nseep1(n4+1:n4+Numnseep)=Nseep
				deallocate(Nseep)
			end if
			Numnseep=n4+Numnseep
			allocate(Nseep(Numnseep))
			Nseep=Nseep1
			deallocate(Nseep1)
			
			Nseep.dof=4
			Nseep.isdead=1

			Nseep.value=Node(Nseep.node).coord(ndimension)
!			node(Nseep.node).property=1
		case('datapoint')
			print *, 'Reading DATAPOINT data...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						ndatapoint=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(datapoint(ndatapoint))
			do i=1,ndatapoint
				call skipcomment(unit)
				read(unit,*) datapoint(i).nnode
				allocate(datapoint(i).node(datapoint(i).nnode))
				call skipcomment(unit)
				read(unit,*) datapoint(i).node
			end do
		case('soilprofile')
			print *, "Reading SOILPROFILE Data..."
			n3=0
			n4=0
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nsoilprofile=int(property(i).value)
					case('spm','soilpressuremethod','spmethod')
						n3=int(property(i).value)
					case('kmethod')
						n4=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(soilprofile(nsoilprofile))
			soilprofile.spm=n3
			soilprofile.kmethod=n4
            ISEXCA2D=1
			
			do i=1,nsoilprofile
				call skipcomment(unit)
				read(unit,'(A64)') soilprofile(i).title
				call skipcomment(unit)				
				read(unit,*) soilprofile(i).nasoil,soilprofile(i).npsoil,soilprofile(i).beam,soilprofile(i).naction,SOILPROFILE(I).NSTRUT
				if(soilprofile(i).nasoil<0) then 
					soilprofile(i).aside=-1
					soilprofile(i).nasoil=-soilprofile(i).nasoil
				endif
				allocate(soilprofile(i).asoil(soilprofile(i).nasoil),soilprofile(i).psoil(soilprofile(i).npsoil), &
						 soilprofile(i).iaction(soilprofile(i).naction),soilprofile(i).istrut(soilprofile(i).nstrut))
				do j=1,soilprofile(i).nasoil
					call skipcomment(unit)
					read(unit,*) soilprofile(i).asoil(j).z,soilprofile(i).asoil(j).mat,soilprofile(i).asoil(j).wpflag,soilprofile(i).asoil(j).sf

				enddo
				do j=1,soilprofile(i).npsoil
					call skipcomment(unit)
					read(unit,*) soilprofile(i).psoil(j).z,soilprofile(i).psoil(j).mat,soilprofile(i).psoil(j).wpflag,soilprofile(i).psoil(j).sf

                enddo
                
				call skipcomment(unit)
				read(unit,*) soilprofile(i).awL,soilprofile(i).sf_awL,soilprofile(i).pwL,soilprofile(i).sf_pwL
				call skipcomment(unit)
				read(unit,*) soilprofile(i).aLoad,soilprofile(i).sf_aLoad,soilprofile(i).pLoad,soilprofile(i).sf_pLoad
				if(soilprofile(i).naction>0) then
					call skipcomment(unit)
					read(unit,*) soilprofile(i).iaction
				endif
				if(soilprofile(i).NSTRUT>0) then
					call skipcomment(unit)
					read(unit,*) soilprofile(i).istrut
				endif				
			end do
		
			
		case('solvercontrol','solver')
			print *, 'Reading SOLVER_CONTROL data'
			do i=1,pro_num
				select case(property(i).name)
					case('type') 
						solver_control.type=int(property(i).value)
					case('solver')
						solver_control.solver=int(property(i).value)
!					case('nincrement','ninc')
!						solver_control.nincrement=int(property(i).value)
!						allocate(solver_control.factor(solver_control.nincrement))
					case('tolerance','tol')
						solver_control.tolerance=property(i).value
					case('dtol')
						solver_control.disp_tol=property(i).value
					case('ftol')
						solver_control.force_tol=property(i).value
					case('niteration','nite')
						solver_control.niteration=int(property(i).value)
					case('output')
						solver_control.output=int(property(i).value)
					case('symmetric','sys')
						if(int(property(i).value)==0) solver_control.issym=.false.
					case('datapaking')
						if(int(property(i).value)==BLOCK) solver_control.datapaking=.false.
					case('ismg')
						if(int(property(i).value)==YES) solver_control.ismg=.true.
					case('islaverify')
						if(int(property(i).value)==YES) solver_control.islaverify=.true.
					case('ispg')
						if(int(property(i).value)==YES) solver_control.ispg=.true.
					case('i2ncal')
						solver_control.i2ncal=int(property(i).value)
					case('bfgm','sim')
						solver_control.bfgm=int(property(i).value)
					case('isfc')
						if(int(property(i).value)==YES) then
							solver_control.isfc=.true.
						else
							solver_control.isfc=.false.
						end if						
!					case('para_spg')
!						solver_control.para_spg=int(property(i).value)
					case('isfu')
						if(int(property(i).value)==YES) then
							solver_control.isfu=.true.
						else
							solver_control.isfu=.false.
						end if
!					case('steady')
!						if(int(property(i).value)==YES) then
!							solver_control.issteady=.true.
!						else
!							solver_control.issteady=.false.
!						end if
					case('mkl')
						if(int(property(i).value)==YES) then
							solver_control.ismkl=.true.
						else
							solver_control.ismkl=.false.
                        end if
                    case('ls','linesearch')
						if(int(property(i).value)==YES) then
							solver_control.isls=.true.
						else
							solver_control.isls=.false.
                        end if                        
                    case('mur')
                        solver_control.mur=int(property(i).value)
					case('barfamilyscale')
						solver_control.barfamilyscale=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do						
!			if(associated(solver_control.factor)) then
!				read(unit,*)   solver_control.factor
!			else
!				!only one increment, set the factor=1.0
!				allocate(solver_control.factor(1))
!				solver_control.factor(1)=1.0
!			end if
		case('ueset')
			print *, 'Reading USER DEFINED ELEMENT SET data'
			if(nueset==1) then !intialize ueset(0)
				ueset(0).enum=enum
				ueset(0).name='all'
				allocate(ueset(0).element(ueset(0).enum))
				do i=1,ueset(0).enum
					ueset(0).element(i)=i
				end do
			end if
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						enum1=int(property(i).value)
					case('name')
						name1=property(i).cvalue
					case default
						call Err_msg(property(i).name)
				end select
			end do
			nueset=nueset+1
			allocate(ueset(nueset).element(enum1))
			n1=0
			n2=0
			ueset(nueset).name=name1
			ueset(nueset).enum=enum1
			do while(n2<enum1)
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				ueset(nueset).element(n2+1:n2+n1)=int(ar(1:n1))
				n2=n2+n1
				do i=1,nset
					do j=0,nueset-1
						if(index(ueset(j).name,set(i))>0)  exit
					end do
					if(j==nueset) then
						print *, 'No such element set. '//trim(set(i))
						stop
					end if
					ueset(nueset).element(n2+1:n2+ueset(j).enum)= &
							ueset(j).element(1:ueset(j).enum)
				end do
				n2=n2+ueset(j).enum
			end do
		case('unset')
			print *, 'Reading USER DEFINED NODE SET data'
			if(nunset==1) then !initialize the unset(0)
				unset(0).nnum=nnum
				unset(0).name='all'
				allocate(unset(0).node(unset(0).nnum))
				do i=1,unset(0).nnum
					unset(0).node(i)=i
				end do
			end if			
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nnum1=int(property(i).value)
					case('name')
						name1=property(i).cvalue					
					case default
						call Err_msg(property(i).name)
				end select
			end do
			nunset=nunset+1
			allocate(unset(nunset).node(nnum1))
			n2=0
			n1=0
			unset(nunset).name=name1
			unset(nunset).nnum=nnum1
			do while(n2<nnum1)
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				unset(nunset).node(n2+1:n2+n1)=ar(1:n1)
				n2=n2+n1
				do i=1,nset
					do j=0,nunset-1
						if(index(unset(j).name,set(i))>0)  exit
					end do
					unset(nunset).node(n2+1:n2+unset(j).nnum)= &
							unset(j).node(1:unset(j).nnum)
				end do
				n2=n2+unset(j).nnum
			end do
		case('sf','step function')
			print *, 'Reading STEP FUNCTION data...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nsf=int(property(i).value)
					case('step')
						nstep=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do		
			allocate(sf(0:nsf))
			do i=1,nsf
				allocate(sf(i).factor(0:nstep))
				sf(i).factor=0.0
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				sf(i).factor(1:nstep)=ar(1:n1)
                IF(NSET==1) SF(I).TITLE=SET(1)
			end do
			nsf=nsf+1 !!
			allocate(sf(0).factor(0:nstep))
			sf(0).factor=1.0d0
			sf(0).factor(0)=0.0d0
		case('time step','ts')
			print *, 'Reading Incremental Time for each step...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nts=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do		
			allocate(timestep(0:nts))
			!usually, nts=nstep,it may be nts=nstep+1
			do i=1,nts
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				j=int(ar(1))
				timestep(j).nsubts=int(ar(2))
				allocate(timestep(j).subts(timestep(j).nsubts))
				timestep(j).subts(1:timestep(j).nsubts)=ar(3:n1)
			end do
			if(.not.allocated(timestep(0).subts)) then
				timestep(0).nsubts=1
				allocate(timestep(0).subts(1))
				timestep(0).subts(1)=0.d0
			end if
		case('stepinfo')
			print *, 'Reading Stepinfo data...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nstepinfo=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do		
			allocate(stepinfo(0:nstepinfo))
			!usually, nstepinfo=nstep
			do i=1,nstepinfo
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				j=int(ar(1))
				stepinfo(j).matherstep=int(ar(2))
				if(int(ar(3))==1) then
					stepinfo(j).issteady=.true.
				else
					stepinfo(j).issteady=.false.
				end if
				if(n1>=4) then
					if(int(ar(4))==1) stepinfo(j).bctype=ramp 
					if(int(ar(4))==-1) stepinfo(j).bctype=Reramp
					if(int(ar(4))==2) stepinfo(j).bctype=step
				end if
				if(n1>=5) then
					if(int(ar(5))==1) stepinfo(j).loadtype=ramp 
					if(int(ar(5))==-1) stepinfo(j).loadtype=Reramp
					if(int(ar(5))==2) stepinfo(j).loadtype=step				
				end if				
			end do
		
        case('wsp','watersurfaceprofile')
            print *, 'Reading WaterSurfaceProfile data...'
            do i=1,pro_num
				select case(property(i).name)
                    CASE('num')
                        nHJump=int(property(i).value)
					!case('caltype')
						!HJump.caltype=int(property(i).value)
                    case('cp')
                        HJump_CP=int(property(i).value)
					case('method')
						n1=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
            end do
			allocate(hjump(nhjump))
			hjump.method=n1
            do i=1,nhjump
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				HJump(i).nseg=int(ar(1))
				HJump(i).nnode=int(ar(2))
				HJump(i).Q=ar(3)				
				HJump(i).B=ar(4)
				HJump(i).UYBC=ar(5)
				HJump(i).DYBC=ar(6)
				if(n1>6) HJump(i).Q_SF=int(ar(7))
				if(n1>7) HJump(i).UYBC_SF=int(ar(8))
				if(n1>8) HJump(i).DYBC_SF=int(ar(9))
				if(n1>9) HJump(i).Caltype=int(ar(10))				
				if(n1>10) HJump(i).g=ar(11)
				if(n1>11) HJump(i).kn=ar(12)
				if(HJump(i).UYBC<0) HJump(i).UYBC_Type=int(HJump(i).UYBC)
				if(HJump(i).DYBC<0) HJump(i).DYBC_Type=int(HJump(i).DYBC)
				allocate(HJump(i).segment(HJump(i).nseg),HJump(i).node(HJump(i).nnode),HJump(i).xy(11,HJump(i).nnode), &
						 HJump(i).HJump(11,2),HJump(i).JTinfo(5,HJump(i).nnode))
				if(HJUMP_CP/=1) allocate(HJump(i).BC_node(HJump(i).nnode))
				HJump(i).xy=0.0
				HJump(i).Hjump=0.d0
				do j=1,HJump(i).nseg
					 call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
					 HJump(i).segment(j).unode=int(ar(1))
					 HJump(i).segment(j).dnode=int(ar(2))
					 HJump(i).segment(j).n=ar(3)
					 HJump(i).segment(j).So=ar(4)
					 if(nset>0) HJump(i).segment(j).profileshape(1)=adjustL(set(1)(1:2))
					 if(nset>1) HJump(i).segment(j).profileshape(2)=adjustL(set(2)(1:2))
				end do    
						   
				call skipcomment(unit)
				read(unit,*) HJump(i).node
				do k=1,HJump(i).nnode
					HJump(i).xy(1:2,k)=node(HJump(i).node(k)).coord(1:2)                    
				end do
			end do

		case('initial value','iv')
			print *,'Reading Initial Value data...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						NiniV=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(inivalue(NiniV))
			do i=1,NiniV
				call strtoint(unit,ar,nmax,n1,n_toread,set,maxset,nset)
				inivalue(i).node=int(ar(1))
				inivalue(i).dof=int(ar(2))
				inivalue(i).value=ar(3)
				if(n1==4) inivalue(i).sf=int(ar(4))
			end do
		
		case('slave_master_node_pair','smnp')
			print *, 'Reading SLAVE-MASTER NODE PAIR'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						nSMNP=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			allocate(SMNP(nSMNP))
			do i=1,nSMNP
				call skipcomment(unit)
				read(unit,*) smnp(i).slave,smnp(i).sdof,smnp(i).master,smnp(i).mdof
			end do
			
		case('geostatic')
			print *, 'Reading GEOSTATIC data...'
			do i=1,pro_num
				select case(property(i).name)
					case('method')
						geostatic.method=int(property(i).value)
					case('soil')
						geostatic.nsoil=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
			end do
			geostatic.isgeo=.true.
			if(geostatic.method==ko_geo) then
				allocate(geostatic.ko(geostatic.nsoil),& 
					geostatic.weight(geostatic.nsoil), &
					geostatic.height(0:geostatic.nsoil))
				call skipcomment(unit)
				read(unit,*) geostatic.ko,geostatic.weight,geostatic.height
			end if
		case('feasible')
			print *, 'Reading LIMIT ANALYSIS FEASIBLE SOLUCTION data'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						n1=int(property(i).value)
					case('eset','element set')
						n2=int(property(i).value)
					case('col')
						n3=int(property(i).value)						
					case default
						call Err_msg(property(i).name)
				end select
			end do	
			if(n3-1/=element(eset(n2).enums).ndof) then
				cstring='the NDOF of the element set  is not consistent with what are read in'
				call Mistake_msg(cstring) 
			end if					
			do i=1,n1
				call skipcomment(unit)
				read(unit,*) n4, ar(1:n3-1)
				n5=eset(n2).enums+n4-1
				do j=1,n3-1
					load(element(n5).g(j))=ar(j)
				end do				
			end do
		case('lf1d')
			print *, 'Reading ONE DIMENSIONAL LINEAR FUNCTION data...'
			do i=1,pro_num
				select case(property(i).name)
					case('num')
						n1=int(property(i).value)
					case default
						call Err_msg(property(i).name)
				end select
				call skipcomment(unit)
				read(unit,*) (LF1D(J,:),J=1,n1)
			end do
		case('coordinate','system')
			print *, 'Reading coordinate system data...'	
				do i=1,pro_num
					select case(property(i).name)
						case('num')
							ncoord=int(property(i).value)
						case default
							call Err_msg(property(i).name)
					end select
				end do
				allocate(coordinate(0:ncoord))
				
				do i=1,ncoord
					call skipcomment(unit)
					read(unit,*) ((coordinate(i).c(j,k),k=1,3),j=1,3)
				end do
				coordinate(0).c(1,1)=1.0d0
				coordinate(0).c(2,2)=1.0d0
				coordinate(0).c(3,3)=1.0d0
		case('origin_of_syscylinder')
			print *, 'Reading the origin of a cylinder system...'
			call skipcomment(unit)
			read(unit,*) Origin_Sys_cylinder
		case('output data','output variable','outdata','outvar')
			print *, 'Reading OUTPUT DATA control keyword'
			!**Attention**, to date, all the output variables keyword must be given in a line.
			!that is, it must be input like that: outvar,x,y,z,...(limited to 1024 character)
			do i=1,pro_num
				select case(property(i).name)
					case('x')
					  outvar(locx).name='X'
					  outvar(locx).value=locx
					  outvar(locx).system=property(i).value
					case('y')
					  outvar(locy).name='Y'  
					  outvar(locy).value=locy
					  outvar(locy).system=property(i).value
					case('z')
					  outvar(locz).name='Z'  
					  outvar(locz).value=locz
					  outvar(locz).system=property(i).value
					case('disx')
					  outvar(disx).name='disx'  
					  outvar(disx).value=disx
					  outvar(disx).system=property(i).value
					case('disy')
					  outvar(disy).name='disy'  
					  outvar(disy).value=disy
					  outvar(disy).system=property(i).value
					case('disz')
					  outvar(disz).name='disz'  
					  outvar(disz).value=disz
					  outvar(disz).system=property(i).value
					case('sxx')
					  outvar(sxx).name='sxx'  
					  outvar(sxx).value=sxx
					  outvar(sxx).system=property(i).value
					case('syy')
					  outvar(syy).name='syy'  
					  outvar(syy).value=syy
					  outvar(syy).system=property(i).value
					case('szz')
					  outvar(szz).name='szz'  
					  outvar(szz).value=szz
					  outvar(szz).system=property(i).value
					case('sxy')
					  outvar(sxy).name='sxy'  
					  outvar(sxy).value=sxy
					  outvar(sxy).system=property(i).value
					case('syz')
					  outvar(syz).name='syz'  
					  outvar(syz).value=syz
					  outvar(syz).system=property(i).value
					case('szx')
					  outvar(szx).name='szx'  
					  outvar(szx).value=szx
					  outvar(szx).system=property(i).value
					case('exx')
					  outvar(exx).name='exx'  
					  outvar(exx).value=exx
					  outvar(exx).system=property(i).value
					case('eyy')
					  outvar(eyy).name='eyy'  
					  outvar(eyy).value=eyy
					  outvar(eyy).system=property(i).value
					case('ezz')
					  outvar(ezz).name='ezz'  
					  outvar(ezz).value=ezz
					  outvar(ezz).system=property(i).value
					case('exy')
					  outvar(exy).name='exy'  
					  outvar(exy).value=exy
					  outvar(exy).system=property(i).value
					case('eyz')
					  outvar(eyz).name='eyz'  
					  outvar(eyz).value=eyz
					  outvar(eyz).system=property(i).value
					case('ezx')
					  outvar(ezx).name='ezx'  
					  outvar(ezx).value=ezx
					  outvar(ezx).system=property(i).value
					case('pexx')
					  outvar(pexx).name='pexx'  
					  outvar(pexx).value=pexx
					  outvar(pexx).system=property(i).value
					case('peyy')
					  outvar(peyy).name='peyy'  
					  outvar(peyy).value=peyy
					  outvar(peyy).system=property(i).value
					case('pezz')
					  outvar(pezz).name='pezz'  
					  outvar(pezz).value=pezz
					  outvar(pezz).system=property(i).value
					case('pexy')
					  outvar(pexy).name='pexy'  
					  outvar(pexy).value=pexy
					  outvar(pexy).system=property(i).value
					case('peyz')
					  outvar(peyz).name='peyz'  
					  outvar(peyz).value=peyz
					  outvar(peyz).system=property(i).value
					case('pezx')
					  outvar(pezx).name='pezx'  
					  outvar(pezx).value=pezx
					  outvar(pezx).system=property(i).value
					case('sxxg')
					  outvar(sxxg).name='sxxg'  
					  outvar(sxxg).value=sxxg
					  outvar(sxxg).system=property(i).value
					case('syyg')
					  outvar(syyg).name='syyg'  
					  outvar(syyg).value=syyg
					  outvar(syyg).system=property(i).value
					case('szzg')
					  outvar(szzg).name='szzg'  
					  outvar(szzg).value=szzg
					  outvar(szzg).system=property(i).value
					case('sxyg')
					  outvar(sxyg).name='sxyg'  
					  outvar(sxyg).value=sxyg
					  outvar(sxyg).system=property(i).value
					case('syzg')
					  outvar(syzg).name='syzg'  
					  outvar(syzg).value=syzg
					  outvar(syzg).system=property(i).value
					case('szxg')
					  outvar(szxg).name='szxg'  
					  outvar(szxg).value=szxg
					  outvar(szxg).system=property(i).value
					case('exxg')
					  outvar(exxg).name='exxg'  
					  outvar(exxg).value=exxg
					  outvar(exxg).system=property(i).value
					case('eyyg')
					  outvar(eyyg).name='eyyg'  
					  outvar(eyyg).value=eyyg
					  outvar(eyyg).system=property(i).value
					case('ezzg')
					  outvar(ezzg).name='ezzg'  
					  outvar(ezzg).value=ezzg
					  outvar(ezzg).system=property(i).value
					case('exyg')
					  outvar(exyg).name='exyg'  
					  outvar(exyg).value=exyg
					  outvar(exyg).system=property(i).value
					case('eyzg')
					  outvar(eyzg).name='eyzg'  
					  outvar(eyzg).value=eyzg
					  outvar(eyzg).system=property(i).value
					case('ezxg')
						outvar(ezxg).name='ezxg'  
						outvar(ezxg).value=ezxg
						outvar(ezxg).system=property(i).value
					case('pexxg')
						outvar(pexxg).name='pexxg'  
						outvar(pexxg).value=pexxg
						outvar(pexxg).system=property(i).value
					case('peyyg')
						outvar(peyyg).name='peyyg'  
						outvar(peyyg).value=peyyg
						outvar(peyyg).system=property(i).value
					case('pezzg')
						outvar(pezzg).name='pezzg'  
						outvar(pezzg).value=pezzg
						outvar(pezzg).system=property(i).value
					case('pexyg')
						outvar(pexyg).name='pexyg'  
						outvar(pexyg).value=pexyg
						outvar(pexyg).system=property(i).value
					case('peyzg')
						outvar(peyzg).name='peyzg'  
						outvar(peyzg).value=peyzg
						outvar(peyzg).system=property(i).value
					case('pezxg')
						outvar(pezxg).name='pezxg'  
						outvar(pezxg).value=pezxg
						outvar(pezxg).system=property(i).value
					case('pw')
						outvar(pw).name='pw'  
						outvar(pw).value=pw
						outvar(pw).iscentre=.true.
					case('mises')
						outvar(sigma_mises).name='mises'
						outvar(sigma_mises).value=sigma_mises
					case('eeq')
						outvar(eeq).name='eeq'
						outvar(eeq).value=eeq
					case('peeq')
						outvar(peeq).name='peeq'
						outvar(peeq).value=peeq
					case('xf')
						outvar(xf_out).name='xf'
						outvar(xf_out).value=xf_out
						outvar(xf_out).system=property(i).value
					case('yf')
						outvar(yf_out).name='yf'
						outvar(yf_out).value=yf_out
						outvar(yf_out).system=property(i).value
					case('zf')
						outvar(zf_out).name='zf'
						outvar(zf_out).value=zf_out
						outvar(zf_out).system=property(i).value
					case('rx')
						outvar(rx).name='rx'
						outvar(rx).value=rx
						outvar(rx).system=property(i).value
					case('ry')
						outvar(ry).name='ry'
						outvar(ry).value=ry
						outvar(ry).system=property(i).value
					case('rz')
						outvar(rz).name='rz'
						outvar(rz).value=rz
						outvar(rz).system=property(i).value
					case('qx')
						outvar(qx).name='qx'
						outvar(qx).value=qx
						outvar(qx).system=property(i).value
					case('qy')
						outvar(qy).name='qy'
						outvar(qy).value=qy
						outvar(qy).system=property(i).value
					case('qz')
						outvar(qz).name='qz'
						outvar(qz).value=qz
						outvar(qz).system=property(i).value	
					case('mx')
						outvar(mx).name='mx'
						outvar(mx).value=mx
						outvar(mx).system=property(i).value
					case('my')
						outvar(my).name='my'
						outvar(my).value=my
						outvar(my).system=property(i).value
					case('mz')
						outvar(mz).name='mz'
						outvar(mz).value=mz
						outvar(mz).system=property(i).value							
					case('gradx','ix')
						outvar(Gradx).name='Ix'
						outvar(Gradx).value=Gradx
					case('grady','iy')
						outvar(Grady).name='Iy'
						outvar(Grady).value=Grady
					case('gradz','iz')
						outvar(Gradz).name='Iz'
						outvar(Gradz).value=Gradz
					case('vx')
						outvar(Vx).name='Vx'
						outvar(Vx).value=Vx
					case('vy')
						outvar(vy).name='Vy'
						outvar(vy).value=vy
					case('vz')
						outvar(vz).name='Vz'
						outvar(vz).value=vz	
					case('head','h')
						outvar(head).name='H'
						outvar(head).value=head
					case('q','discharge')
						outvar(discharge).name='Q'
						outvar(discharge).value=discharge
					case('phead','ph','pressure head')
						outvar(phead).name='PH'
						outvar(phead).value=Phead
					case('kr')
						outvar(kr_spg).name='Kr'
						outvar(kr_spg).value=kr_spg
					case('mw')
						outvar(mw_spg).name='mw'
						outvar(mw_spg).value=mw_spg						
					case default
						call Err_msg(property(i).name)
				end select
			end do			
								
		case default
			call Err_msg(term)
	end select


end subroutine

subroutine write_readme_feasolver()	
	use solverds
	use ifport
	implicit none
	integer::i,j,item
	LOGICAL(4)::tof,pressed
	!integer,external::ipp
	integer,parameter::nreadme=1024
	character(1024)::readme(nreadme)
	
    print *, "The help file is in d:\README_FEASOLVER.TXT."
	open(2,file='d:\README_FEASOLVER.TXT',STATUS='REPLACE')
	
	I=0
	README(IPP(I)) ="//THE KEYWORD STRUCTURE USED IN THE INPUT FILE SINP IS EXPLAINED HEREIN"
	README(IPP(I)) ="//THE [] MEANS OPTIONAL."
	README(IPP(I)) ="//THE | MEANS OR(或)."
	README(IPP(I)) ="//THE CHARACTER INSIDE () MEANS THE DATATYPE OR AN ARRAY."
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//TITLE"
	README(IPP(I))=  "//"//'"'//"THE KEYWORD TITLE IS USED TO INPUT THE INFOMATION OF THE MODEL."//'"'
	README(IPP(I))= "//{TITLE(A)} "
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//NODE,NUM=...(I) [,DATAPACKING=1|2] [,DEMENSION=1|2|3]   // NUM=节点数"
	README(IPP(I))=  "//"//'"'//"THE KEYWORD NODE IS USED TO INPUT THE NODAL INFOMATION."//'"'
	README(IPP(I)) = "//{X(R),Y(R)[,Z(R)])} //DATAPAKING=1.|"
	README(IPP(I)) = "//{X1(R),...,XNUM(R),Y1(R),...,YNUM(R)[,Z1(R),...,ZNUM(R),])} //DATAPAKING=2 "
	README(IPP(I)) =  "//{......}   //当DATAPAKING=1,共NUM行; 当DATAPAKING=2,共DEMENSION*NUM个数 "

	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//ELEMENT,NUM=...(I),ET=...(A),MATID=...(I)[,SET=...(I),SYSTEM=1]  // NUM=单元个数,ET=单元类型,MATID=材料号,SET=单元集号,单元局部坐标。此关键词可重复出现。"
	README(IPP(I)) = "                                                                  //当ET=BEAM时,SYSTEM=局部坐标，为梁单元的y轴定向; | "
    README(IPP(I))=  "//"//'"'//"THE KEYWORD ELEMENT IS USED TO INPUT THE ELEMENT INFOMATION."//'"'
	README(IPP(I)) = "//{N1(I),N2(I),...,NN(I)} //N为单元节点号; |"
	README(IPP(I)) = "//{N1(I),N2(I),...,NN(I),H} //当ET=DKT3,SHELL3,SHELL3_KJB时, H=单元的厚度"
	README(IPP(I)) =  "//{......}   //共NUM行. "

	
	Do j=1,2
		README(IPP(I)) ="\N//******************************************************************************************************"C
		if(j==1) README(IPP(I)) = "//BC,NUM=(I)[,SF=(I),SSP_ONEPILE=(I),SPG_ISDUAL=(I)]   //NUM=节点约束个数,SF=时间因子，SSP_ONEPILE=是否只作用在一根钢板桩上(0,NO).此关键词可重复出现。"  
		if(j==2) README(IPP(I)) = "//LOAD,NUM=(I)[,SF=(I),SSP_ONEPILE=(I),SPG_ISDUAL=(I)]   //NUM=节点荷载个数,SF=时间因子，SSP_ONEPILE=是否只作用在一根钢板桩上(0,NO).此关键词可重复出现。"  
		README(IPP(I))=  "//"//'"'//"THE KEYWORD BC IS USED TO INPUT NODAL CONSTRAINS."//'"'
		README(IPP(I)) = "//{NODE(I),DOF(I),VALUE(R)[,SF(I),SPG_ISDUAL(I),SSP_ONEPILE(I)]}  //ISDUAL:如果isdual==i(>0),则表示此自由度可能与出溢边界Nseep(i)重复，如果边界水头小于位置水头，则变为出溢边界。"  
		README(IPP(I)) = "//{...}  //共NUM行"	
		README(IPP(I)) = "//注意，对于水头边界(dof=4)，如果边界值小于其相应的位置水头，则认为该边界无效，不起作用。"
		README(IPP(I)) = "//注意，多步计算时，对于渗流模型（SOLVER_CONTROL.TYPE=SPG）,由于水头边界(dof=4)不具有叠加性，所以输入时要求每一步的水头均是总量，而不是增量."	
		README(IPP(I)) = "//对于力学模型（SOLVER_CONTROL.TYPE=SLD）,多步计算时，由于位移边界具有叠加性，所以每一步的位移边界均是增量."
	end do
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//SEEPAGE FACE,NUM=...(I)，STEP FUNCTION=...(I)   //NUM=出溢点的个数,STEP FUNCTION=出溢点的时间步函数，默认为0"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD SEEPAGE FACE IS USED TO INPUT THE NODES CONSTRAINED BY A SEEPAGE FACE CONDITION."//'"'
	README(IPP(I)) = "//{N1(I),N2(I),...,NN(I)]} //节点号，共NUM个。此行可重复出现，直至节点数=NUM." 
	README(IPP(I)) = "//此关键词可重复出现，以输入不同STEP FUNCTION的出溢点."
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//BODY FORCE,NUM=...(I)  //NUM=单元荷载个数"
	README(IPP(I))=  "//"//'"'//"THE KEYWORD BODY FORCE IS USED TO INPUT ELEMENTAL LOADS."//'"'
	README(IPP(I)) = "//{E1,E2,...,EN,DOF,VALUE(R),STEPFUNC.}  //Ei为单元编号或单元组名。此行可重复出现，直至单元个数=NUM."  
	README(IPP(I)) = "// 当Ei为单元组名时，该单元组前面必须用关键词UESET定过."
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//ELT_LOAD,NUM=...(I)  //NUM=单元荷载行数 //此关键词可取代BODY FORCE. 此关键词目前不能使用，需进一步完善."
	README(IPP(I))=  "//"//'"'//"THE KEYWORD ELT_LOAD IS USED TO INPUT LOADS APPLIED ON AN ELEMENT GROUP."//'"'
	README(IPP(I)) = "//{ELTGROUP(I),DOF(I),VALUE(I),STEPFUNC.(I)}  //ELTGROUP=I, 即关键词ELEMENT中定义的SET号.亦即为ESET(I)的单元."  
	README(IPP(I)) = "//{......} //共NUM行. "

	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//TIME STEP,NUM=...(I)  //NUM=个数."
	README(IPP(I))=  "//"//'"'//"THE KEYWORD TIME STEP IS USED TO INPUT THE SUBINCREMENTAL TIME FOR EACH STEP IN A TRANSIENT ANALYSIS."//'"'
	README(IPP(I)) = "//{ISTEP(I),NSUBTIMESTEP(I),TIMESTEP(1)(R),TIMESTEP(2)(R),...,TIMESTEP(STEP)(R)}  //共NSUBTIMESTEP个时间,总的分析时间步长为各子步长之和."  
	README(IPP(I)) = "//{......} //共NUM行. "
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//INITIAL VALUE,NUM=...(I)   //NUM=初值个数"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD BC IS USED TO INITIAL VALUE DATA."//'"'
	README(IPP(I)) = "//{NODE(I),DOF(I),VALUE(R)[,STEPFUNC.(I)]}"  
	README(IPP(I)) = "//{...}  //共NUM行"	
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//STEPINFO,NUM=...(I)   //NUM=步信息个数"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD STEPINFO IS USED TO STEP INFOMATION DATA."//'"'
	README(IPP(I)) = "//{ISTEP(I),MATHERSTEP(I),ISSTEADY(I),ISSTEADY(I)[,BCTYPE,LOADTYPE]} //ISTEP:STEP NUMBER; MATHERSTEP:此步的依托步; ISSTEADY:是否稳态分析, 1,Yes,others NO."  
	README(IPP(I)) = "//LOADTYPE(BCTYPE):为荷载(位移边界)施加方式，=1,表示步内荷载(位移边界)随时间线性施加，=2(default)，表示步荷载(位移边界)在步初瞬间施加。"
    README(IPP(I)) = "//{...}  //共NUM行"	
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//STEP FUNCTION,NUM=...(I),STEP=...(I)   //NUM=步方程的个数,STEP=步数."  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD BC IS USED TO STEP FUNCTION DATA."//'"'
	README(IPP(I)) = "//{FACTOR(1)(R),FACTOR(2)(R),...,FACTOR(STEP)(R),TITILE(A)& 
                         \N// FACTOR(ISTEP)=第ISTEP步边界或荷载的系数. &
                         \N//当FACTOR(ISTEP)=-999时,此边界或荷载在此步中失效（无作用）. &
                         \N//!表单元生死时，0为死1为生。"C  
	README(IPP(I)) = "//{...}  //共NUM行"
	README(IPP(I)) = "//注意,对于力学模型（SOLVER_CONTROL.TYPE=SLD），输入的是各步荷载或位移边界的增量;而对渗流模型（SOLVER_CONTROL.TYPE=SPG）,输入的是各步水头或流量边界的总量."

	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//SLAVE_MASTER_NODE_PAIR,NUM=...(I)   //NUM=约束节点对的个数."  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD SMNP IS USED TO SLAVE-MASTER NODE PAIR DATA."//'"'
	README(IPP(I)) = "//{SLAVE,SDOF,MASTER,MDOF} //SLAVE节点号，SLAVE自由度，MASTER节点号，MASTER自由度， "  
	README(IPP(I)) = "//{...}  //共NUM行.!注意，master点上的mdof自由度上目前不能施加位移边界条件，这时输入时请互换slave和master."
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//WSP,NUM=...(I)[CP=...(I),Method=...(I)]   //CP=1,仅为计算水面算,水面线计算完成后就退出。CP=2,渗流计算是边界按不考虑水跃作用取值。Mothed=1,2,3,4(kinds,WangXG,Ohtsu,Chow)"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD WSP IS USED TO INPUT WATERSURFACEPROFILE CALCULATION DATA."//'"'
	README(IPP(I)) = "//{NSEGMENT(I),NNODE(I),Q(R),B(R),UYBC,DYBC,[Q_SF,UYBC_SF,DYBC_SF,caltype,g,kn]}" 
	README(IPP(I)) = "//流道数;流道剖分总节点数;过流量;流道宽;上游边界水深;下游边界水深; [Q的步长函数,UYBC的步长函数,DYBC的步长函数,计算控制参数;重力加速度;曼宁量纲系数]"
	README(IPP(I)) = "//{UNODE(I),DNODE(I),n(R),So(R),[Profileshape(1),Profileshape(2)]}  //起点号（局部编号，最上游节点编号为1，最下游编号为NNODE),终点号,糙率,坡率,[急流形式,缓流形式]。(流道参数行，从上游到下游依次输入,共NSEGMENT行)"
    README(IPP(I)) = "//{N1,N2,...,N(NNODE)}  //流道内节点（全局）编号,共NNODE个，从上游往下游输入。"
	README(IPP(I)) = "//注：Profileshape=M1,M2,M3,S1,S2,S3,H2,H3,A2,A3,C1,C3 "
	README(IPP(I)) = "//注：UYBC（DYBC）=-1,表示上游（下游）边界水深为临界水深，=-2，表示上游（下游）边界水深为正常水深。"
    README(IPP(I)) = "//注：CALTYPE=1，只算急流；=2，只算缓流；=0（默认），两者都算."
    README(IPP(I)) = "//注：对于/=4(Chow)，目前只能处理NSEGMENT=2的情况，即斜坡段+水平段，且上游在左下游在右.默认水平段与斜坡段的交点为第二段的第一个节点。"
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//SOILPROFILE,NUM=(I),spmethod=(I),kmethod=(I)   //spmethod=土压力计算方法，0，郎肯； kmethod=基床系数的计算方法，0，m法；1，(E,V)法；2,zhu;3 biot;4 vesic;-1,按直接输入"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD WSP IS USED TO INPUT SOILPROFILE DATA."//'"'
	README(IPP(I))=  "//A0:{TITLE(C)}  //土层剖面的名字"  
	README(IPP(I)) = "//A:{NASOIL(I),NPSOIL(I),BEAMID(I),NACTION(I),NSTRUT}  //主动侧土层数(负数表主动土压力为负，被动为正，反之亦然。)，被动侧土层数，地基梁号,约束(力，位移，弹簧)个数,支撑个数" 
	README(IPP(I)) = "//B:{(Z1,Z2,MAT,WPMETHOD,STEPFUN)*NASOIL}   //层顶高程点号，层底高程点号，材料号，水压力考虑方法(0=合算，1=常规分算，2=分算，考虑渗透力),步函数。共NASOIL行"  
	README(IPP(I)) = "//C:{(Z1,Z2,MAT,WPMETHOD,STEPFUN)*NPSOIL}   //层顶高程点号，层底高程点号，材料号，水压力考虑方法(0=合算，1=常规分算，2=分算，考虑渗透力),步函数。共NPSOIL行"  
	README(IPP(I)) = "//D:{AWATERLEVEL,ASTEPFUN,PWATERLEVEL,PSTEPFUN}   //主动侧水位,主动侧水位步函数，被动侧水位,被动侧水位步函数，"  
	README(IPP(I)) = "//E:{ALoad,ALoadSTEPFUN,PLoad,PLoadSTEPFUN}   //主动侧超载,主动侧超载步函数，被动侧超载,被动侧超载步函数，" 
	README(IPP(I)) = "//F:{NO_ACTION(I)}*NACTION   //约束号，共NACTION个" 
	README(IPP(I)) = "//G:{NO_STRUT(I)}*NSTRUT   //支撑号，共NSTRUT个" 
	README(IPP(I)) = "//{A0,A,B,C,D,E,F,G}*NUM。   //共NUM组"
	README(IPP(I)) = "//注意：\n1)每一时间步，土层按顺序从上而下输入，不同时间步间的土层可以重叠。 &
						\n//2)各时间步地下水位处要分层;桩顶处要分层(如果桩在土里面);桩的材料分界处要分层。 &
						\n//3)考虑渗透力时，假定awL>pwL. &
						\n//4)如果水面高于地表，将水等效为为土层（令c,phi,模量均设为0，渗透系数<=0)"C
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//PILE,NUM=...(I)"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD WSP IS USED TO INPUT BEAM(RetainingStructure) DATA."//'"'
	README(IPP(I)) = "//A:{NSEG(I),[SYSTEM=0]}  //材料分段数，坐标号" 
	README(IPP(I)) = "//B:{Z(1:NSEG+1)}   //材料分段点,应从上往下（或从左往右）输入（方便单元寻址）"  
	README(IPP(I)) = "//C:{MAT(1:NSEG)}   //各段材料号"  
	README(IPP(I)) = "//{A,B,C}*NUM。   //共NUM组"	

	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//STRUT,NUM=...(I)"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD WSP IS USED TO INPUT STRUT(RetainingStructure) DATA."//'"'
	README(IPP(I)) = "//A:{Z,MAT,STEPFUN}  //点号，材料号，步函数" 
	README(IPP(I)) = "//{A}*NUM。   //共NUM组"
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//KPOINT,NUM=...(I)"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD WSP IS USED TO INPUT KeyPoint DATA."//'"'
	README(IPP(I)) = "//A:{NO(I),XY(1:NDIMENSION),[ELEMENTSIZE(R)]}  //点号，XY(1:NDIMENSION),[ELEMENT SIZE]" 
 	README(IPP(I)) = "//{A}*NUM。   //共NUM组"	
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//ACTION,NUM=...(I)"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD WSP IS USED TO INPUT Laction DATA..."//'"'
	README(IPP(I))=  "//A0:{TITLE(C)}  //作用的名字"  
	README(IPP(I)) = "//A:{NKP,TYPE,DOF,NDIM,[SF,ISVALUESTEPFUN,ISEXVALUE]}  //控制点数，作用类型（0=力，1=位移，2=刚度），作用的自由度，作用的维度，生死步函数,值步函数开关(0N1Y)，极值开关(0N1Y)" 
	README(IPP(I)) = "//B:{KPOINT(1:NKP)}  //控制点号,应从上往下（或从左往右）输入（方便单元寻址）" 
	README(IPP(I)) = "//C:{VALUE(1:NKP)}  //控制点上作用的大小。注意单位统一(线作用的宽度取决于支护桩的间距)，当ndim=1,type=2时，单位：F/L^3;(ndim=1,type=1,L); (ndim=1,type=0,F/L^2) "
	README(IPP(I)) = "//D:{SF(1:NKP)}  //控制点上作用的步函数，如果isstepfun=1."
	README(IPP(I)) = "//E:{EXVALUE(1:NKP,1:2)}  //控制点上作用的上下限值(先各点下限(exvalue(:,1))，后各点上限(exvalue(:,2))) 如果isexvalue=1."
 	README(IPP(I)) = "//{A0,A,B,C,D,E}*NUM。   //共NUM组"
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//HINGE,NUM=...(I) //(此功能目前仅对beam2d及beam单元有效)"  
	README(IPP(I))=  "//"//'"'//"THE KEYWORD HINGE IS USED TO INPUT HINGE/FREEDOF DATA..."//'"'
	README(IPP(I)) = "//A:{ELEMENT,NODE,DOF}  //(要释放的自由度所在的)单元，节点和自由度编号。" 
 	README(IPP(I)) = "//{A}*NUM。   //共NUM组"
	    
    
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) = "//MATERIAL,MATID=...(I),[TYPE=...(I)],[ISFF=YES|NO],[NAME=...(c)],ISSF=...(I)//MATID=材料号，TYPE=材料类型，ISFF=是否为依赖某场变量,NAME=材料文字注释.此关键词可重复出现.ISSF=是否输入材料参数的步函数(0N1Y)" 
	README(IPP(I))=  "//"//'"'//"THE KEYWORD MATERIAL IS USED TO INPUT MATERIAL INFOMATION."//'"'
	README(IPP(I)) = "//{A: MATERIAL.PROPERTIES}  //PLEASE REFER TO THE EXPLANATION IN THE END OF THE FILE."
	README(IPP(I)) = "//[B:{FIELD FUNCTION PARAMETERS}]  // 如ISFF=YES "	
	README(IPP(I)) = "//[C:{STEPFUNCTION(1:NPARAMETERS)}]  // 如ISSF=YES "	
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) ="//MATERIAL.PROPERTY (FYI)" 
	README(IPP(I)) ="//1. CASE (CONDUCT): PROPERTY(1)=K0 .(2)=K1  "
	README(IPP(I)) ="//THE CONDUCTIVITY K=K0+K1*FIELD VARIABLE\n"c
	README(IPP(I)) ="//2. CASE (LA_MC)  : PROPERTY(1)=P  .(2)=PHI .(3)=C	.(4)=GANMA	.(5)=Pore Pressure"
	README(IPP(I)) ="//GANMA=SPECIFIED GRAVITY OF SOIL\N"c
	README(IPP(I)) ="//3. CASE(ELASTIC) : PROPERTY(1)=E  .(2)=V\n"C
	README(IPP(I)) ="//4. CASE(MISES)   : PROPERTY(1)=E  .(2)=V   .(3)=SIGMA_Y  .(4)=GAMA"
	README(IPP(I)) ="//SIGMA_Y=YIELD STRESS UNDER UNIAXIAL STRETCH. FOR CLAY UNDER PLAIN STRAIN SIGMA_Y=3*CU (CU, UNDRAINED SHEAR STRENGTH) AND SIGMA_Y=2*CU FOR TRIAXIAL (AXISYMMETRICAL) STATE.\N"C
	README(IPP(I)) ="//5. CASE(MC)      : PROPERTY(1)=E  .(2)=V   .(3)=C\N   "C
	README(IPP(I)) ="//6. CASE(CAMCLAY) : PROPERTY(1)=M  .(2)=V   .(3)=LAMDA \N  "C
	README(IPP(I)) ="//7. CASE(SPG)     : PROPERTY(1)=K1 .(2)=K2  .(3)=K3       .(4)=INT(TRANSM)    .(7)=ALPHA .(8)=N  .(9)=M .(10)=Mv	.(11)=Sita_s	.(12)=Sita_r    .(13)=rw "
	README(IPP(I)) ="//TRANSM=L2G,FOR SPG, TRANSFORM THE MATERIAL KIJ TO GLOBLE KXY."
    README(IPP(I)) ="//ALPHA= A CURVE FITTING PARAMETER FOR THE VAN GENUCHTEN MODEL,LEONG AND RAHARDJO MODEL AND EXPONENT MODEL,UNIT=1/L." 
    README(IPP(I)) ="//N,M=CURVE FITTING DIMENSIONLESS PARAMETERS FOR THE VAN GENUCHTEN MODEL/LEONG AND RAHARDJO MODEL." 
    README(IPP(I)) ="//FOR THE VAN GENUCHTEN MODEL, THE DEFAULT M=1-1/N, AND M IS OMITTED FROM INPUT."
    README(IPP(I)) ="//Mv=COEFFICIENT OF COMPRESSIBILITY.(UNIT:L**2/F)"
    README(IPP(I)) ="//Sita_s=Saturated volumetric water content."
	README(IPP(I)) ="//Sita_r=Residual volumetric water content."
    README(IPP(I)) ="//rw=bulk Gravity of water.(UNIT:F/L**3)\N"C
    README(IPP(I)) ="//注意单位的统一。尤其注意ALPHA的单位，在VG模型中为：1/L，在LR模型中为:L.\N"C
	README(IPP(I)) ="//8. CASE(BAR,BAR2D)     : PROPERTY(1)=E  .(2)=A	[.(3)=hy	.(4)=hz	 .(5)=minN(最大轴向压力)	.(6)=MaxN(最大轴向拉力)]"
	README(IPP(I)) ="//9. CASE(BEAM,BEAM2D,SSP2D)   : PROPERTY(1)=E  .(2)=A   .(3)=v	.(4)=J	.(5)=Iz	.(6)=Iy	[.(7)=hy	.(8)=hz]"
    README(IPP(I)) ="//                          [PROPERTY(9)=MinN .(10)=MaxN .(11)=minMx .(12)=maxMx .(13)=minMy .(14)=maxMy .(15)=minMz .(16)=maxMz]"
    README(IPP(I)) ="//                          [.(17)=yc ]"
	README(IPP(I)) ="//J,IY,IZ ARE REFERRED TO THE LOCAL COORDINATE SYSTEM."
	README(IPP(I)) ="//当为单元SSP2D指定材料，输入参数(A,Iz,minN,maxN,minMz,maxMz)均为单根钢板桩的参数,YC钢板桩形心轴距离锁口内沿的距离。"
	README(IPP(I)) ="//hy,hz分别为梁截面在y'和z'轴方向(局部坐标)的高度，为后处理转化为六面体单元时所用. \N"C
	README(IPP(I)) ="//当为支护桩时，hy,hz分别为桩径和桩距，计算作用于支护桩上的土压力和土弹簧的刚度用 \N"C
	README(IPP(I)) ="//10. CASE(PIPE2,PPIPE2) : PROPERTY(1)=R(管半径,L)  .(2)=LAMDA(管壁摩阻系数)	.(3)=EPSLON(管壁的绝对粗糙度,L)	.(4)=V(运动粘滞系数L**2/T)"C
	README(IPP(I)) ="//11. CASE(ExcavationSoil) : PROPERTY(1:8)=黏聚力，摩擦角，天然/饱和重度，变形模量，泊松比,渗透系数，水平基床系数(F/L**3),墙土间摩擦角（度）"C
	README(IPP(I)) ="//12. CASE(spirng) : PROPERTY(1:3)=k,minV(发生负位移),maxV(发生正位移)，预加力，预加位移"C

						
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) ="//Coordinate system(FYI)" 
	README(IPP(I)) ="//对于2D问题,重力方向为Y轴方向，且向上为正,X轴向右为正."
	README(IPP(I)) ="//对于3D问题,重力方向为Z轴方向，且向上为正,水平面为XY平面,XYZ满足右手螺旋法则"
	README(IPP(I)) ="//弹簧类单元的局部坐标系与整体坐标系相同。"C
	
	README(IPP(I)) ="\N//******************************************************************************************************"C
	README(IPP(I)) ="//DOF (FYI)" 
	README(IPP(I)) ="//Except for axisymmetric elements, the degrees of freedom are always referred to as follows:" 
	README(IPP(I)) ="//1 x-displacement /limit analysis vx" 
	README(IPP(I)) ="//2 y-displacement /limit analysis vy" 
	README(IPP(I)) ="//3 z-displacement " 
	README(IPP(I)) ="//4 Pore pressure, hydrostatic fluid pressure, scale field variable" 
	README(IPP(I)) ="//5 Rotation about the x-axis, in radians" 
	README(IPP(I)) ="//6 Rotation about the y-axis, in radians" 
	README(IPP(I)) ="//7 Rotation about the z-axis, in radians" 
	README(IPP(I)) ="//Here the x-, y-, and z-directions coincide with the global X-, Y-, and Z-directions, respectively." 
	
	do j=1,i
		item=len_trim(readme(j))
		write(2,20) readme(j)
	end do
	
	tof=system("D:\README_FEASOLVER.TXT")	
	
20	format(a<item>)
	
	contains
	
	integer function ipp(i) 
		implicit none
		integer,intent(inout)::i
		
		i=i+1
		ipp=i
		if(ipp>nreadme) then
			print *, "The length of README is", nreadme
			stop
		end if
				
	end function
	
end subroutine


   !把字符串中相当的数字字符(包括浮点型)转化为对应的数字
   !如 '123'转为123,'14-10'转为14,13,12,11,10
   !string中转化后的数字以数组ar(n1)返回，其中,n1为字符串中数字的个数:(注　1-3转化后为3个数字：1,2,3)
   !nmax为数组ar的大小,string默认字符长度为1024。
   !num_read为要读入数据的个数。
   !unit为文件号
   !每次只读入一个有效行（不以'/'开头的行）
   !每行后面以'/'开始的后面的字符是无效的。
   subroutine  strtoint(unit,ar,nmax,n1,num_read,set,maxset,nset)
	  implicit none
	  logical::tof1,tof2
	  integer::i,j,k,strl,ns,ne,n1,n2,n3,n4,step,nmax,& 
			num_read,unit,ef,n5,nsubs,maxset,nset
	  real(8)::ar(nmax),t1
		character(32)::set(maxset)
	  character(1024)::string
	  character(32)::substring(100)
	  character(16)::legalC,SC

		LegalC='0123456789.-+eE*'
		sc=',; '//char(9)
		n1=0
		nset=0
		ar=0
		!set(1:maxset)=''
	  do while(.true.)
		 read(unit,'(a1024)',iostat=ef) string
		 if(ef<0) then
			print *, 'file ended unexpected. sub strtoint()'
			stop
		 end if

		 string=adjustL(string)
		 strL=len_trim(string)
		 
		do i=1,strL !remove 'Tab'
			if(string(i:i)/=char(9)) exit
		end do
		string=string(i:strL)
		string=adjustl(string)
		strL=len_trim(string)
		if(strL==0) cycle

		 if(string(1:1)/='/'.and.string(1:1)/='#') then
			
			!每行后面以'/'开始的后面的字符是无效的。
			if(index(string,'/')/=0) then
				strL=index(string,'/')-1
				string=string(1:strL)
				strL=len_trim(string)
			end if

			nsubs=0
			n5=1
			do i=2,strL+1
				if(index(sc,string(i:i))/=0.and.index(sc,string(i-1:i-1))==0) then
					nsubs=nsubs+1					
					substring(nsubs)=string(n5:i-1)					
				end if
				if(index(sc,string(i:i))/=0) n5=i+1
			end do
			
			do i=1, nsubs
				substring(i)=adjustl(substring(i))				
				n2=len_trim(substring(i))
				!the first character should not be a number if the substring is a set.
				if(index('0123456789-+.', substring(i)(1:1))==0) then
					!set
					nset=nset+1
					set(nset)=substring(i)
					cycle
				end if
				n3=index(substring(i),'-')
				n4=index(substring(i),'*')
				tof1=.false.
				if(n3>1) then
				    tof1=(substring(i)(n3-1:n3-1)/='e'.and.substring(i)(n3-1:n3-1)/='E')
				end if
				if(tof1) then !处理类似于'1-5'这样的形式的读入数据
					read(substring(i)(1:n3-1),'(i8)') ns
					read(substring(i)(n3+1:n2),'(i8)') ne
					if(ns>ne) then
						step=-1
					else
						step=1
					end if
					do k=ns,ne,step
						n1=n1+1
						ar(n1)=k
					end do				     	
				else
				     tof2=.false.
				     if(n4>1) then
				             tof2=(substring(i)(n4-1:n4-1)/='e'.and.substring(i)(n4-1:n4-1)/='E')
				     end if
					if(tof2) then !处理类似于'1*5'(表示5个1)这样的形式的读入数据
						read(substring(i)(1:n4-1),*) t1
						read(substring(i)(n4+1:n2),'(i8)') ne
						ar((n1+1):(n1+ne))=t1
						n1=n1+ne
					else
						n1=n1+1
						read(substring(i),*) ar(n1)
					end if	
				end if			
			end do
		 else
			cycle
		 end if
		
		 if(n1<=num_read) then
		    exit
		 else
		    if(n1>num_read)  print *, 'error!nt2>num_read. i=',n1
		 end if
	
	  end do	

   end subroutine

subroutine translatetoproperty(term)

!**************************************************************************************************************
!Get a keyword and related property values from a control line (<1024)
!input variables:
!term, store control data line content.
!ouput variables:
!property,pro_num
!mudulus used:
!None
!Subroutine called:
!None
!Programmer:LUO Guanyong
!Last updated: 2008,03,20

!Example: 
!term='element, num=10,type=2,material=1,set=3'
!after processed,the following data will be returned:
!term='element'
!property(1).name=num
!property(1).value=1
!.....
!**************************************************************************************************************
	use solverds
	implicit none
	integer::i,strL
	character(1024)::term,keyword
	integer::ns,ne,nc
	character(32)::str(50)
	
	if(index(term,'/')/=0) then !每一行‘/’后面的内容是无效的。
		strL=index(term,'/')-1
		term=term(1:strL)
	end if
	
	term=adjustl(term)
	ns=1
	ne=0
	nc=0
	property.name=''
	property.value=0.0
	property.cvalue=''
	do while(len_trim(term)>0) 
		nc=nc+1
		if(nc>51) then
			print *, 'nc>51,subroutine translatetoproperty()'
			stop
		end if
		ne=index(term,',')
		if(ne>0.and.len_trim(term)>1) then
			str(nc)=term(ns:ne-1)
			str(nc)=adjustL(str(nc))
		else 
		!no commas in the end
			ne=min(len_trim(term),len(str(nc)))
			str(nc)=term(ns:ne)
			str(nc)=adjustL(str(nc))
		end if
		term=term(ne+1:len_trim(term))
		term=adjustL(term)		
	end do

	term=str(1)
	pro_num=nc-1
	do i=2,nc
		ne=index(str(i),'=')
		if(ne>0) then
			property(i-1).name=str(i)(1:ne-1)
			ns=len_trim(str(i))-ne
			call inp_ch_c_to_int_c(str(i)(ne+1:len_trim(str(i))),ns,property(i-1).value,property(i-1).cvalue)
		else
			property(i-1).name=str(i)(1:len_trim(str(i)))
		end if
		!read(str(i)(ne+1:len_trim(str(i))),*) property(i-1).value
	end do

end subroutine


subroutine ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,EC1)
!according to the element type return how many nodes for each this type element, and how many dofs
!for each this type element
!initializing the element class property
	use solverds
	implicit none
	integer::et1,nnum1,ndof1,ngp1,nd1,EC1
	character(16)::stype

	ngp1=0
	nd1=0

	select case(et1)
		case(CONDUCT1D)
			nnum1=2
			ndof1=2
			stype='FELINESEG'
			ec1=CND
		case(UB3)
			nnum1=3
			ndof1=6
			stype='FETRIANGLE'
			ec1=LMT
		case(UBZT4)
			nnum1=4
			ndof1=8
			stype='FEQUADRILATERAL'
			ec1=LMT
		case(LB3)
			nnum1=3
			ndof1=9
			stype='FETRIANGLE'
			ec1=LMT
		case(LBZT4)
			nnum1=4
			ndof1=12
			stype='FEQUADRILATERAL'
			ec1=LMT
		case(CPE3,CPS3,CAX3)
			nnum1=3
			ndof1=6
			ngp1=1
			nd1=4
			stype='FETRIANGLE'
			if(et1==cpe3)then
				EC1=CPE
			end if
			if(et1==cps3)EC1=cps
			if(et1==CAX3)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)
		case(CPE6,CPS6,CAX6)
			nnum1=6
			ndof1=12
			ngp1=3
			nd1=4
			stype='FETRIANGLE'
			if(et1==cpe6) then
				ec1=CPE
			end if
			if(et1==cpS6)	ec1=cps
			if(et1==CAX6)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)			
		case(CPE4,CPS4,cax4)
			nnum1=4
			ndof1=8
			ngp1=4			
			nd1=4
			stype='FEQUADRILATERAL'
			if(et1==cpe4) then
				ec1=CPE
			end if
			if(et1==cpS4)	ec1=cps
			if(et1==CAX4)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)			
		case(CPE4R,CPS4R,CAX4R)
			nnum1=4
			ndof1=8
			ngp1=1			
			nd1=4
			stype='FEQUADRILATERAL'	
			if(et1==cpe4r) then
				ec1=CPE
			end if
			if(et1==cpS4R)	ec1=cps
			if(et1==CAX4r)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)			
		case(CPE8,CPS8,CAX8)
			nnum1=8
			ndof1=16
			ngp1=9
			nd1=4
			stype='FEQUADRILATERAL'
			if(et1==cpe8) then
				ec1=CPE
			end if
			if(et1==CPS8)	ec1=cps
			if(et1==CAX8)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)			
		case(CPE8R,CPS8R,CAX8R)
			nnum1=8
			ndof1=16
			ngp1=4
			nd1=4
			stype='FEQUADRILATERAL'
			if(et1==cpe8r) then
				ec1=CPE
			end if
			if(et1==CPS8R)	ec1=cps
			if(et1==CAX8r)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)			
		case(CPE15,CPS15,CAX15)
			nnum1=15
			ndof1=30
			ngp1=12
			nd1=4
			stype='FETRIANGLE'
			if(et1==cpe15) then
				ec1=CPE
			end if
			if(et1==CPS15)	ec1=cps
			if(et1==CAX15)then
				EC1=CAX
			end if
			call EL_SFR2(ET1)
		!case(PRM6)
		!	nnum1=6
		!	ndof1=18
		!	ngp1=2
		!	nd1=6
		!	stype='FEBRICK'
		!	EC1=C3D
		!	call EL_SFR2(ET1)
		!case(PRM15)
		!	nnum1=15
		!	ndof1=45
		!	ngp1=9
		!	nd1=6
		!	stype='FETETRAHEDRON' !
		!	EC1=C3D
		!	call EL_SFR2(ET1)
		!case(TET10)
		!	nnum1=10
		!	ndof1=30
		!	ngp1=4
		!	nd1=6
		!	stype='FETETRAHEDRON' !
		!	EC1=C3D
		!	call EL_SFR2(ET1)			
		case(CPE3_SPG,CAX3_SPG,CPE3_CPL,CAX3_CPL)
			nnum1=3
			!ndof1=3
			ngp1=1
			
			stype='FETRIANGLE'
			IF(ET1==CPE3_SPG) then
				EC1=SPG2D;NDOF1=3;nd1=2
			endif
			if(et1==CAX3_SPG) then
				EC1=CAX_SPG;NDOF1=3;nd1=2
			endif
			IF(ET1==CPE3_CPL) THEN
				EC1=CPL;NDOF1=9;nd1=4
			ENDIF
			if(et1==CAX3_CPL) THEN
				EC1=CAX_CPL;NDOF1=9;nd1=4
            ENDIF
			call EL_SFR2(ET1)
		case(CPE6_SPG,CAX6_SPG,CPE6_CPL,CAX6_CPL)
			nnum1=6
			!ndof1=6
			ngp1=3
			
			stype='FETRIANGLE'
            
			IF(ET1==CPE6_SPG) THEN
				EC1=SPG2D;NDOF1=6;nd1=2
			ENDIF
			if(et1==CAX6_SPG) THEN
				EC1=CAX_SPG;NDOF1=6;nd1=2
			ENDIF
			IF(ET1==CPE6_CPL) THEN
				EC1=CPL;NDOF1=18;nd1=4
			ENDIF
			if(et1==CAX6_CPL) THEN
				EC1=CAX_CPL;NDOF1=18;nd1=4
            ENDIF
			call EL_SFR2(ET1)			
		case(CPE4_SPG,cax4_SPG,CPE4_CPL,cax4_CPL)
			nnum1=4
			!ndof1=4
			ngp1=4			
			
			stype='FEQUADRILATERAL'
			IF(ET1==CPE4_SPG) THEN
				EC1=SPG2D;NDOF1=4;nd1=2
			ENDIF
			if(et1==CAX4_SPG) THEN
			EC1=CAX_SPG;NDOF1=4;nd1=2
			ENDIF
			IF(ET1==CPE4_CPL) THEN
			EC1=CPL;NDOF1=12;nd1=4
			ENDIF
			if(et1==CAX4_CPL) THEN
			EC1=CAX_CPL;NDOF1=12;nd1=4
			ENDIF
			call EL_SFR2(ET1)
            
		case(CPE4R_SPG,CAX4R_SPG)
			nnum1=4
			!ndof1=4
			ngp1=1			
			
			stype='FEQUADRILATERAL'	
			IF(ET1==CPE4R_SPG) THEN
			EC1=SPG2D;NDOF1=4;nd1=2
			ENDIF
			if(et1==CAX4R_SPG) THEN
			EC1=CAX_SPG;NDOF1=4;nd1=2
			ENDIF
			IF(ET1==CPE4R_CPL) THEN
			EC1=CPL;NDOF1=12;nd1=4
			ENDIF
			if(et1==CAX4R_CPL) THEN
			EC1=CAX_CPL;NDOF1=12;nd1=4
			ENDIF
            
			call EL_SFR2(ET1)			
		case(CPE8_SPG,CAX8_SPG,CPE8_CPL,CAX8_CPL)
			nnum1=8
			!ndof1=8
			ngp1=9
			
			stype='FEQUADRILATERAL'
			IF(ET1==CPE8_SPG) THEN
			EC1=SPG2D;NDOF1=8;nd1=2
			ENDIF
			if(et1==CAX8_SPG) THEN
			EC1=CAX_SPG;NDOF1=8;nd1=2
			ENDIF
			IF(ET1==CPE8_CPL) THEN
			EC1=CPL;NDOF1=24;nd1=4
			ENDIF
			if(et1==CAX8_CPL) THEN
			EC1=CAX_CPL;NDOF1=24;nd1=4  
			ENDIF
            
			call EL_SFR2(ET1)			
		case(CPE8R_SPG,CAX8R_SPG,CPE8R_CPL,CAX8R_CPL)
			nnum1=8
			!ndof1=8
			ngp1=4
			
			stype='FEQUADRILATERAL'
			IF(ET1==CPE8R_SPG) THEN
			EC1=SPG2D;NDOF1=8;nd1=2
			ENDIF
			if(et1==CAX8R_SPG) THEN
			EC1=CAX_SPG;NDOF1=8;nd1=2
			ENDIF
			IF(ET1==CPE8R_CPL) THEN
			EC1=CPL;NDOF1=24;nd1=4
			ENDIF
			if(et1==CAX8R_CPL) THEN
			EC1=CAX_CPL;NDOF1=24;nd1=4 
  			ENDIF
			call EL_SFR2(ET1)	
            
		case(CPE15_SPG,CAX15_SPG,CPE15_CPL,CAX15_CPL)
			nnum1=15
			!ndof1=15
			ngp1=12
			
			stype='FETRIANGLE'
			IF(ET1==CPE15_SPG) THEN
			EC1=SPG2D;NDOF1=15;nd1=2
			ENDIF
			if(et1==CAX15_SPG) THEN
			EC1=CAX_SPG;NDOF1=15;nd1=2
			ENDIF
			IF(ET1==CPE15_CPL) THEN
			EC1=CPL;NDOF1=45;nd1=4
			ENDIF
			if(et1==CAX15_CPL) THEN
			EC1=CAX_CPL;NDOF1=45;nd1=4           
			ENDIF			
			call EL_SFR2(ET1)
		case(PRM6_SPG,PRM6,PRM6_CPL)
			nnum1=6
			!ndof1=6
			ngp1=2
			!nd1=3
			stype='FEBRICK'
			IF(ET1==PRM6_SPG) THEN
			EC1=SPG;NDOF1=6;nd1=3
			ENDIF
            IF(ET1==PRM6) THEN
			EC1=C3D;NDOF1=18;nd1=6
			ENDIF
            IF(ET1==PRM6_CPL) THEN
			EC1=CPL;NDOF1=24;nd1=6
            ENDIF
			call EL_SFR2(ET1)
		case(PRM15_SPG,PRM15,PRM15_CPL)
			nnum1=15
			!ndof1=15
			ngp1=9
			!nd1=3
			stype='FETETRAHEDRON' !
			IF(ET1==PRM15_SPG) THEN
			EC1=SPG;NDOF1=15;nd1=3
			ENDIF
            IF(ET1==PRM15) THEN
			EC1=C3D;NDOF1=45;nd1=6
			ENDIF
            IF(ET1==PRM15_CPL) THEN
			EC1=CPL;NDOF1=60;nd1=6
            ENDIF
			call EL_SFR2(ET1)
		case(tet4_spg,TET4,TET4_CPL)
			nnum1=4
			!ndof1=4
			ngp1=1
			
			stype='FETETRAHEDRON'
			IF(ET1==TET4_SPG) THEN
			ec1=SPG;NDOF1=4;nd1=3
			ENDIF
			IF(ET1==TET4_CPL) THEN
			ec1=CPL;NDOF1=16;nd1=6
			ENDIF
			IF(ET1==TET4) THEN
			ec1=C3D;NDOF1=12;nd1=6
			ENDIF
			CALL EL_SFR2(ET1)
		case(tet10_spg,TET10,TET10_CPL)
			nnum1=10
			!ndof1=10
			ngp1=4
			
			stype='FETETRAHEDRON'
			
			IF(ET1==TET10_SPG) THEN
			ec1=SPG;NDOF1=10;nd1=3
			ENDIF
			IF(ET1==TET10_CPL) THEN
			ec1=CPL;NDOF1=40;;nd1=6
			ENDIF
			IF(ET1==TET10) THEN
			ec1=C3D;NDOF1=30;nd1=6
			ENDIF
			CALL EL_SFR2(ET1)	
		case(BAR) !3d BAR ELEMENT
			nnum1=2
			ndof1=6
			nd1=6
			stype='FEBRICK' !
			EC1=STRU
			!call EL_SFR2(ET1)
		case(BAR2D) !3d BAR ELEMENT
			nnum1=2
			ndof1=4
			nd1=4
			stype='FEBRICK' !
			EC1=STRU			
		case(BEAM) !3D Beam element
			nnum1=2
			ndof1=12
			nd1=12
			stype='FEBRICK'
			EC1=STRU
		case(BEAM2D,SSP2D) !2D Beam element
			nnum1=2
			ndof1=6
			nd1=6
			stype='FEBRICK'
			EC1=STRU
		case(PE_SSP2D)
			nnum1=2
			ndof1=2
			nd1=2
			stype='FELINESEG'
			EC1=PE
		case(SSP2D1) !2D Beam element
			nnum1=2
			ndof1=10
			nd1=10
			stype='FEBRICK'
			EC1=STRU

		case(SHELL3,SHELL3_KJB)
			NNUM1=3
			NDOF1=18
			ND1=3
			STYPE='FETRIANGLE'
			EC1=STRU
		case(DKT3)
			NNUM1=3
			NDOF1=9
			ND1=3
			STYPE='FETRIANGLE'
			EC1=STRU
		case(pipe2,ppipe2)
			NNUM1=2
			NDOF1=2
			ND1=2
			STYPE='FELINESEG'
			EC1=PIPE
		case(springx,springy,springz,springmx,springmy,springmz)
			nnum1=1
			ndof1=1
			nd1=1
			stype='FELINESEG'
			ec1=spring
		case(SOILSPRINGX,SOILSPRINGY,SOILSPRINGZ)
			nnum1=1
			ndof1=1
			nd1=1
			stype='FELINESEG'
			ec1=soilspring
        CASE DEFAULT
            PRINT *, "NO SUCH ELEMENT TYPE. IN SUB ettonnum. TO BE IMPROVED."
            STOP
	end select

end subroutine

subroutine Err_msg(cstring)
	use dflib
	implicit none
	character(*)::cstring
	character(64)::term
	integer(4)::msg

	term='No such Constant: '//trim(cstring)
	msg = MESSAGEBOXQQ(term,'Caution'C,MB$ICONASTERISK.OR.MB$OKCANCEL.OR.MB$DEFBUTTON1)
	if(msg==MB$IDCANCEL) then
		stop
	end if	
	
end subroutine

subroutine Mistake_msg(cstring)
	use dflib
	implicit none
	character(*)::cstring
	character(128)::term
	integer(4)::msg

	term="Mistake:  "//trim(cstring)
	msg = MESSAGEBOXQQ(term,'Mistake'C,MB$ICONSTOP.OR.MB$OK.OR.MB$DEFBUTTON1)
	if(msg==MB$IDOK) then
		stop
	end if	
	
end subroutine

subroutine skipcomment(unit,EF)
	implicit none
	integer,intent(in)::unit
    INTEGER,OPTIONAL::EF
	integer::i,strL,EF1
	character(1024) string
	
	do while(.true.)
		read(unit,'(a1024)',iostat=ef1) string
		if(ef1<0) then
            IF(PRESENT(EF)) THEN
                EF=EF1
                RETURN
            END IF
			print *, 'file ended unexpected. sub skipcomment()'
			stop
		end if

		string=adjustL(string)
		strL=len_trim(string)

		do i=1,strL !remove 'Tab'
			if(string(i:i)/=char(9)) exit
		end do
		string=string(i:strL)
		string=adjustl(string)
		strL=len_trim(string)
		if(strL==0) cycle

		if(string(1:1)/='/'.and.string(1:1)/='#') then
			backspace(unit)
			exit
		end if
	end do
	
end subroutine



!subroutine GenElement_EXCA() !STRUCTURAL MESH
!	!use solverds
!	use excaDS
!    use SOLVERLIB
!	implicit none
!	integer::i,j,k,K1,IAR(500),NAR=500,NNODE1=0,NEL1=0,N1=0,N2=0,IDP,JDP,IPILE,ISP1,IAC1
!	real(double)::DPOINT1(3,1000)=0,t1
!	INTEGER::et1,nnum1,ndof1,ngp1,nd1,ec1
!	CHARACTER(16)::STYPE,CH1,CH2
!    CHARACTER(32)::TITLE1=""
!    !integer,allocatable::kpelement(:)
!	type(node_tydef),ALLOCATABLE::node1(:),NODE2(:)
!    type(element_tydef),ALLOCATABLE::element1(:),ELEMENT2(:)
!	type(bc_tydef),allocatable::bf1(:),bf2(:)
!	
!	
!    allocate(kpelement(2,nkp)) 
!	!单元定位表,记录与每个控制点相连在单元在element()中的编号，(1,i)为i点的上（左）边的单元，(2,i)则为i点的下（右）边的单元
!	!假定梁从左往右或从上往下输入。
!	kpnode=0
!    kpelement=0
!    
!	do i=1,NSOILPROFILE
!	
!	    IPILE=SOILPROFILE(I).BEAM
!        
!		ALLOCATE(element1(10000))
!		ALLOCATE(node1(NNUM+1:NNUM+10000))	
!		NNODE1=NNUM
!		NEL1=0
!		
!		ET1=BEAM2D		
!		call ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,ec1)
!		
!		do j=1,PILE(IPILE).nseg	

!			NAR=SIZE(IAR)
!			call aovis2d(PILE(IPILE).kpoint(j),PILE(IPILE).kpoint(j+1),IAR,NAR)
!			do k=1,NAR-1
!                IDP=3
!                JDP=1000
!				call divideLine2D(kpoint(1,IAR(k)),kpoint(ndimension,IAR(k)),kpoint(ndimension+1,IAR(k)), &
!                                  kpoint(1,IAR(k+1)),kpoint(ndimension,IAR(k+1)),kpoint(ndimension+1,IAR(k+1)),&
!                                  DPOINT1,IDP,JDP)
!                
!				kpnode(iar(k))=nnode1+1
!                kpnode(iar(k+1))=nnode1+JDP !!!!
!                if(kpelement(2,iar(k))==0) then
!					kpelement(2,iar(k))=enum+nel1+1
!				else
!					stop "ERROR #1 OCCURED IN SUB GenElement_EXCA"
!				endif
!				 if(kpelement(1,iar(k+1))==0) then
!					kpelement(1,iar(k+1))=enum+nel1+JDP-1
!				else
!					stop "ERROR #2 OCCURED IN SUB GenElement_EXCA"
!				endif
!                
!                
!                N1=JDP-1
!				IF(J==PILE(IPILE).NSEG.and.(K==NAR-1)) N1=JDP
!                DO K1=1,NDIMENSION
!                    NODE1((NNODE1+1):(NNODE1+N1)).COORD(K1)=DPOINT1(K1,1:N1)
!				ENDDO
!                DO K1=1,JDP-1
!                    NEL1=NEL1+1
!                    ELEMENT1(NEL1).NNUM=NNUM1
!					ALLOCATE(ELEMENT1(NEL1).NODE(NNUM1))
!                    ELEMENT1(NEL1).NODE(1)=NNODE1+K1
!                    ELEMENT1(NEL1).NODE(2)=ELEMENT1(NEL1).NODE(1)+1
!                    ELEMENT1(NEL1).MAT=PILE(IPILE).MAT(J)
!					ELEMENT1(NEL1).ET=BEAM2D
!					element1(NEL1).ndof=ndof1
!					element1(NEL1).ngp=ngp1
!					element1(NEL1).nd=nd1
!					element1(NEL1).ec=ec1
!					ELEMENT1(NEL1).SET=NESET+1 !!!!
!					!ELEMENT(NEL1).SYSTEM=0  !!!!!
!                ENDDO				
!                NNODE1=NNODE1+N1
!                
!            enddo
!			
!		enddo
!		
!		neset=neset+1
!		eset(neset).num=NESET
!		eset(neset).stype=stype
!		eset(neset).grouptitle="BEAM"
!		eset(neset).et=et1
!		eset(neset).ec=ec1
!		eset(neset).system=0  !!!!!
!		eset(neset).enums=enum+1
!		
!		allocate(element2(enum+NEL1),PILE(IPILE).ELEMENT(NEL1))
!		element2(1:enum)=element(1:enum)
!		element2(enum+1:ENUM+NEL1)=element1(1:NEL1)
!		if(allocated(element))	deallocate(element)
!		deallocate(element1)
!		enum=enum+NEL1
!		eset(neset).enume=enum
!		allocate(element(enum))
!		element=element2
!		deallocate(element2)
!        DO J=1,NEL1
!            PILE(IPILE).ELEMENT(J)=eset(neset).ENUMS-1+J
!        ENDDO
!		pile(ipile).nel=nel1
!        
!		
!		allocate(NODE2(NNODE1),PILE(IPILE).NODE(NNODE1-NNUM))
!		NODE2(1:NNUM)=NODE(1:NNUM)
!		NODE2(NNUM+1:NNODE1)=NODE1
!        
!        DO J=NNUM+1,NNODE1
!            PILE(IPILE).NODE(J-NNUM)=J
!        ENDDO
!		pile(ipile).nnode=nnode1-nnum
!		
!		ALLOCATE(PILE(IPILE).NODE2BCLOAD(NNUM+1:NNODE1),pile(ipile).Nlength(NNUM+1:NNODE1))
!		CALL enlarge_bc(BC_LOAD,BL_NUM,pile(ipile).nnode,N1)
!		FORALL (J=1:PILE(IPILE).NNODE)
!			BC_LOAD(N1+J-1).NODE=NNUM+J
!			PILE(IPILE).NODE2BCLOAD(NNUM+J)=N1+J-1
!			BC_LOAD(N1+J-1).DOF=1
!		ENDFORALL
!        
!		if(allocated(NODE))	deallocate(NODE)
!		deallocate(NODE1)
!		NNUM=NNODE1
!		allocate(NODE,SOURCE=NODE2)
!		deallocate(NODE2)
!		
!		pile(ipile).nlength=0.0d0
!		do j=1,pile(ipile).nnode-1
!			t1=0.d0
!			do k1=1,ndimension
!				t1=t1+(node(pile(ipile).node(j)).coord(k1)-node(pile(ipile).node(j+1)).coord(k1))**2
!			enddo
!			t1=t1**0.5
!			pile(ipile).Nlength(pile(ipile).node(j:j+1))=pile(ipile).Nlength(pile(ipile).node(j:j+1))+t1/2.0d0
!		enddo
!		
!		
!		!防止竖向失稳，在底部生成1坚向弹簧单元
!		CALL enlarge_element(ELEMENT,ENUM,1,N1)
!		element(n1).et=springy
!		element(n1).nnum=1
!		allocate(element(n1).node(1))
!		element(n1).node(1)=pile(ipile).node(pile(ipile).nnode)
!		et1=springy
!		call ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,ec1)
!		element(n1).ndof=ndof1
!		element(n1).ngp=ngp1
!		element(n1).nd=nd1
!		element(n1).ec=ec1
!		element(n1).property(2)=-1.d20
!		element(n1).property(3)=1.d20
!		element(n1).property(4)=1.0d7
!		
!		nel1=2*pile(ipile).nnode
!		n1=nnum-pile(ipile).nnode
!		allocate(element1(nel1),pile(ipile).element_sp(2,n1+1:nnum),pile(ipile).BeamResult(n1+1:nnum,pile(ipile).NVA,nstep))
!		pile(ipile).element_sp=0.d0
!		pile(ipile).BeamResult=0.d0
!		
!		
!		
!		et1=SOILSPRINGX
!		call ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,ec1)
!		element1.nnum=1
!		element1.et=SOILSPRINGX
!		element1.ndof=ndof1
!		element1.ngp=ngp1
!		element1.nd=nd1
!		element1.ec=ec1
!		element1.isactive=0
!		do j=1,pile(ipile).nnode						
!			allocate(element1(2*j-1).node(1),element1(2*j).node(1))
!			element1(2*j-1).node(1)=pile(ipile).node(j)			
!			element1(2*j).node(1)=pile(ipile).node(j)
!			pile(ipile).element_sp(1,pile(ipile).node(j))=enum+2*j-1 !!!!
!			pile(ipile).element_sp(2,pile(ipile).node(j))=enum+2*j !!!!
!		enddo
!		
!		neset=neset+1
!		eset(neset).num=NESET
!		eset(neset).stype=stype
!		eset(neset).grouptitle="soilspring"
!		eset(neset).et=et1
!		eset(neset).ec=ec1
!		eset(neset).system=0  !!!!!
!		eset(neset).enums=enum+1
!		
!		allocate(element2(enum+NEL1))
!		element2(1:enum)=element(1:enum)
!		element2(enum+1:ENUM+NEL1)=element1(1:NEL1)
!		if(allocated(element))	deallocate(element)
!		deallocate(element1)
!		enum=enum+NEL1
!		eset(neset).enume=enum
!		allocate(element(enum))
!		element=element2
!		deallocate(element2)
!		
!		
!        
!        !ueset,unset
!        do j=1, soilprofile(i).nasoil
!            
!			if(kpnode(soilprofile(i).asoil(J).z(1))>0) then
!                N1=SOILPROFILE(I).ASOIL(J).Z(1)
!                N2=SOILPROFILE(I).ASOIL(J).Z(2)
!                WRITE(CH1,'(I3)') I
!                WRITE(CH2,'(I3)') J
!                TITLE1="SP_"//TRIM(CH1)//"ASOIL_"//TRIM(CH2)
!				CALL Gen_USER_NSET_EXCA(N1,N2,TITLE1,SOILPROFILE(I).ASOIL(J).IUNSET)
!				CALL Gen_USER_ESET_EXCA(N1,N2,TITLE1,SOILPROFILE(I).ASOIL(J).IUESET)							 
!			else
!				print *, "The soilprofile(i).asoil(j) has no corresponding elements.i,j=",i,j
!					
!			endif

!        end do
!        
!	    do j=1, soilprofile(i).npsoil
!            
!			if(kpnode(soilprofile(i).psoil(J).z(1))>0) then
!                N1=SOILPROFILE(I).psoil(J).Z(1)
!                N2=SOILPROFILE(I).psoil(J).Z(2)
!                WRITE(CH1,'(I3)') I
!                WRITE(CH2,'(I3)') J
!                TITLE1="SP_"//TRIM(CH1)//"psoil_"//TRIM(CH2)
!				CALL Gen_USER_NSET_EXCA(N1,N2,TITLE1,SOILPROFILE(I).psoil(J).IUNSET)
!				CALL Gen_USER_ESET_EXCA(N1,N2,TITLE1,SOILPROFILE(I).psoil(J).IUESET)							 
!			else
!				print *, "The soilprofile(i).psoil(j) has no corresponding elements.i,j=",i,j
!					
!			endif

!        end do
!		
!        do j=1,soilprofile(i).naction
!			IAC1=soilprofile(i).iaction(j)
!			if(action(IAC1).NDIM==1) then
!				
!				N1=action(IAC1).KPOINT(1)
!				N2=action(IAC1).KPOINT(ACTION(IAC1).NKP)
!				TITLE1=ACTION(IAC1).TITLE
!				CALL Gen_USER_NSET_EXCA(N1,N2,TITLE1,ACTION(IAC1).IUNSET)
!				CALL Gen_USER_ESET_EXCA(N1,N2,TITLE1,ACTION(IAC1).IUESET)
!                NNODE1=UNSET(ACTION(IAC1).IUNSET).NNUM
!				
!			elseif(action(IAC1).NDIM==0) then
!				
!				DO K=1,action(IAC1).NKP
!					action(IAC1).node(k)=kpnode(action(IAC1).kpoint(k))
!				ENDDO	
!                NNODE1=action(soilprofile(i).iaction(j)).NKP
!                
!            endif 
!            
!			select case(action(IAC1).TYPE) 
!				case(2) !生成弹簧单元
!					NEL1=NNODE1
!                    CALL enlarge_element(ELEMENT,ENUM,NEL1,N1)
!					action(iac1).istiffelement=n1
!					action(iac1).nstiffelement=nel1
!					allocate(action(iac1).node2stiffelement(nnum))
!					action(iac1).node2stiffelement=0
!					
!					element(N1:enum).sf=action(iac1).sf
!					
!                    DO K=0,NEL1-1
!                        ALLOCATE(ELEMENT(N1+K).NODE(1))
!                        IF(ACTION(IAC1).NDIM==1) THEN
!                            ELEMENT(N1+K).NODE(1)=UNSET(ACTION(IAC1).iunset).NODE(K+1)
!							
!                        ELSEIF(ACTION(IAC1).NDIM==0) THEN
!                            ELEMENT(N1+K).NODE(1)=ACTION(IAC1).NODE(K+1)
!                        ENDIF
!						action(iac1).node2stiffelement(ELEMENT(N1+K).NODE(1))=n1+k	
!                    ENDDO
!					
!                        
!					!ALLOCATE(ACTION(IAC1).STIFFELEMENT(NEL1))
!					!DO K=1,NEL1
!					!	ACTION(IAC1).STIFFELEMENT(K)=N1+K-1
!					!ENDDO
!					IF(ACTION(IAC1).DOF<=3) THEN					
!						et1=SPRINGX-1+ACTION(IAC1).DOF
!					ELSE
!						et1=SPRINGX+ACTION(IAC1).DOF
!					ENDIF
!					call ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,ec1)
!					element(N1:).nnum=1
!					element(N1:).et=et1
!					element(N1:).ndof=ndof1
!					element(N1:).ngp=ngp1
!					element(N1:).nd=nd1
!					element(N1:).ec=ec1
!					
!				case(1) !生成位移边界

!                    CALL enlarge_bc(BC_DISP,BD_NUM,NNODE1,N1)
!					action(iac1).nbcnode=nnode1
!					action(iac1).ibcnode=n1
!					allocate(action(iac1).node2bcdisp(nnum))
!					!BC_DISP.SF=
!                    IF(ACTION(IAC1).NDIM==1) THEN
!                        bc_disp(n1:).node=UNSET(ACTION(IAC1).iunset).NODE						
!                    ELSEIF(ACTION(IAC1).NDIM==0) THEN
!                        bc_disp(n1:).node=ACTION(IAC1).NODE
!                    ENDIF                    
!					bc_disp(n1:).dof=action(iac1).dof
!					
!					!bc_disp(n1:).sf=action(iac1).sf
!					
!					forall (k=n1:bd_num) action(iac1).node2bcdisp(bc_disp(k).node)=k	
!				case(0) !生成力边界

!                    CALL enlarge_bc(BC_LOAD,BL_NUM,NNODE1,N1)
!					action(iac1).iloadnode=n1
!					action(iac1).nloadnode=nnode1
!					allocate(action(iac1).node2bcload(nnum))
!					action(iac1).node2bcload=0
!                    IF(ACTION(IAC1).NDIM==1) THEN
!                        bc_LOAD(n1:).node=UNSET(ACTION(IAC1).iunset).NODE
!                    ELSEIF(ACTION(IAC1).NDIM==0) THEN
!                        bc_LOAD(n1:).node=ACTION(IAC1).NODE						
!                    ENDIF 
!					forall (k=n1:bL_num) action(iac1).node2bcload(bc_load(k).node)=k
!					BC_LOAD(N1:).dof=action(iac1).dof
!					!BC_LOAD(N1:).sf=action(iac1).sf

!			end select
!            
!        enddo
!		
!    enddo
!        
!		
!	CALL enlarge_element(ELEMENT,ENUM,NSTRUT,N1)	
!            
!	DO J=1,NSTRUT
!		
!				
!		IF(STRUT(J).ISBAR==0) THEN
!			ET1=SPRINGX
!			ALLOCATE(ELEMENT(N1+J-1).NODE(1))
!			ELEMENT(N1+J-1).NODE(1)=KPNODE(STRUT(J).Z(1))
!		ELSE
!			ET1=BAR2D
!			ALLOCATE(ELEMENT(N1+J-1).NODE(2))
!			ELEMENT(N1+J-1).NODE=KPNODE(STRUT(J).Z)
!		ENDIF
!		ELEMENT(N1+J-1).SF=STRUT(J).SF
!		ELEMENT(N1+J-1).MAT=STRUT(J).MAT
!		STRUT(J).ELEMENT=N1+J-1

!		call ettonnum(et1,nnum1,ndof1,ngp1,nd1,stype,ec1)
!		element(N1+J-1).nnum=NNUM1
!		element(N1+J-1).et=et1
!		element(N1+J-1).ndof=ndof1
!		element(N1+J-1).ngp=ngp1
!		element(N1+J-1).nd=nd1
!		element(N1+J-1).ec=ec1				
!				
!	ENDDO				

!	
!	
!    call checkdata()
!   

!endsubroutine
