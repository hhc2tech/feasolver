  
    !定义求解器的数据结构
	!节点
module solverds

    
	
	include 'constant.h'
    
   
    
	type node_tydef
		real(kind=DPN)::coord(3)=0.0D0 !coordinates (x,y,z)
		integer::ndof=0 !节点的自由度个数
		integer::dof(MNDOF)=inactive !-9999999,inactive dof; >0:active dof. if dof()>0, then it indexes the dof number.						 		
		real(kind=DPN),allocatable::stress(:),strain(:),pstrain(:)
		real(kind=DPN),allocatable::FQ(:),M(:) !nodal shear forces and nodal bending moments.
		real(kind=DPN),allocatable::igrad(:),velocity(:)	!for spg element, gradients,velocities.
		real(kind=DPN)::angle=0.0D0 !the angle around the vertex.
		real(kind=DPN)::MISES=0.0D0,EEQ=0.0D0,PEEQ=0.0D0
		real(kind=DPN)::Q=0.0D0,Kr=0.0D0,Mw=0.0D0  !nodal flux,relative permeability,slope of volumetric water content.		
		integer::nelist=0
		integer,allocatable::elist(:) !elements sharing the node.
!		integer::Property=0 !for SPG, Property=1 suggesting that the node is on the seepage surface.
	end type
	integer::nnum !节点数
	type(node_tydef),allocatable::node(:)
    
	type element_tydef
		integer::nnum !node numbers of this element
		integer,allocatable::node(:) !单元的节点
        integer,allocatable::node2(:) !为方便Bar和Beam单元的后处理，为单元集内的节点编号，将其转换成实体六面体单元后输出。
		integer::et  !单元类型
		integer::mat,mattype  !material id and material type.the paramters is got from material(mat)
		!for et=soilspring, mat=-1,主动侧单元，mat=-2,被动侧单元
		integer::set=1 !element set
		integer::ndof !total dofs of the element
		integer::ngp !the number of gauss points		
		integer::isactive=1 !1Y0N。
        INTEGER::SF=0 !STEP FUNCTION .FACTOR=0,DEATICE;FACTOR=1,ACTIVE
		integer::sign=1 !for soilspring element .sign=1, Pa,Po,Pp,Pw=+; sign=-1, pa,po,pp,pw=-.
					!for pe_ssp2d,ngp=i指向smnp(i).		
		integer::nd ! the dimension of the strain-stress matrix
		integer::id  !element id number in the set
		integer::ec=0 !element class
		integer::nspr=0 ! the patch number sharing the element
		integer::layer=1 !element layer, for horizontal seepage analysis; 
						!for sectional seepage analysis, =1, all nodes are under water table,=-1,all nodes are above water talbe,=0 cross the water table
		integer::ifreedof=-1 !>0,表铰接点,指向freedof(ifreedof)
		
		!integer::status=1 !=1,fixed(default); =2,slip;=0:free.
		integer::referencestep=1 !=i,表明此单元变形计算初始参考状态起点为第i步结束的位移场。        
		integer::system=0 !local coordinate system, =0,global coordinate
		! local coordinate system for bar element:
		! x-axis is along the bar and the positive direction is from node 1 to node 2
		! y and z is trivial for bar element.
		! local coordinate systme for beam element:
		! x-axis is along the bar and the positive direction is from node 1 to node 2
		! y and z is defined by user but must be consistent with right hand rule.
		!and be consistent with Iy and Iz.
		real(kind=DPN)::property(6)=0.0D0  !for spg problem and iniflux is used, property(3)=low lamda,property(2)=up lamda
		real(kind=DPN),allocatable::angle(:)!internal angle for every nodes
		integer,allocatable::g(:) !单元的定位向量
		real(kind=DPN),allocatable::km(:,:) !单元的单刚,km(ndof,ndof)
		real(kind=DPN),allocatable::CMM(:,:) !Consistent mass matrix
		real(kind=DPN),allocatable::B(:,:,:)  !B matrix, B(nd,ndof,ngp+nnum)
		real(kind=DPN),allocatable::D(:,:)  !elastic strain-stress Matrix, D(nd,nd), its shape depends on the
										!for element cpe3_spg D stores the initial km
		real(kind=DPN),allocatable::detjac(:) ! the determinant of jacobian matrix in each gauss point. 
		real(kind=DPN),allocatable::stress(:,:),Dstress(:,:) !stress at gauss points and nodes, stress(6,ngp+nnum)
		real(kind=DPN),allocatable::strain(:,:),Dstrain(:,:) !strain at gauss points and nodes, strain(6,ngp+nnum)
														!for cpe3_spg, strain(2,2),strain(:,1)=gradient, strain(:,2)=velocity
		real(kind=DPN),allocatable::pstrain(:,:) !total plastic strain in gp and centroid
		real(kind=DPN),allocatable::evp(:,:) !plastic strain incremental of each incremental in gp and centroid.
		real(kind=DPN),allocatable::xygp(:,:) !globe co-ordinates of gausian points.
		real(kind=DPN),allocatable::ev(:) !evolution variable in each gausian point.
		real(kind=DPN),allocatable::e(:) !void ratio of each gausian point
		real(kind=DPN),allocatable::GForce(:),DGforce(:) !the cumulative general force of each dof in globle system,Gf(ndof),useful for structure elements
														!the nodal discharges, for spg element.
                                                        !Dgforce(:),每步内力增量。
		real(kind=DPN),allocatable::GForceILS(:) !the nodal force in the local system.
        !real(kind=DPN)::reference
 		real(kind=DPN),allocatable::G2L(:,:) !transformation matrix from global system to local system
		!For SPG elements
		real(kind=DPN),allocatable::igrad(:,:) !hydraulic gradient igrad(nd,ngp+nnum)
		real(kind=DPN),allocatable::velocity(:,:) !seepage velocity, velocity(nd,ngp+nnum)
		real(kind=DPN),allocatable::flux(:) !flux
		real(kind=DPN),allocatable::Kr(:) !relative permeability
		real(kind=DPN),allocatable::Mw(:) !slope of volumetric water content
		real(kind=DPN),allocatable::sita_fin(:),sita_ini(:) !volume water content in the end and start of the time step.  
        		
		!real(kind=DPN),allocatable::lamda(:) !lamda(ngp)=1.0(by default),relative k. 
		!additional variables for upper bound analysis
		real(kind=DPN),allocatable::A12(:,:)  ! for UBZT4 is A23
		real(kind=DPN),allocatable::X2(:)
	end type
	integer::enum=0 !节点数
	type(element_tydef),allocatable::element(:)
	
	
	!step function
	type stepfun_tydef
		real(kind=DPN),allocatable::factor(:)
        character(64)::title=""
		!注意,输入的是各步荷载或位移边界的增量.
		!当FACTOR(ISTEP)=-999时,此边界或荷载在此步中失效（无作用）.	
        !表单元生死时，0为死1为生。
	endtype
	type(stepfun_tydef),allocatable::sf(:)
	integer::nsf=0
	integer::nstep=1	
	!the value of the default step function sf(0)
	!sf(0).factor(0)=0 !the 0 step is for geotechnical initial stress calculation.at this step
	!all  boundaries and loads are 0 exept for the gravity.
	!sf(0).factor(1:nstep)=1.0
	
	type subtimestep_tydef
		integer::nsubts
		real(kind=DPN),allocatable::subts(:)
		!real(kind=DPN),allocatable::subfactor(:)
	end type
	type(subtimestep_tydef),allocatable::TimeStep(:)
!	real(kind=DPN),allocatable::TimeStep(:) !timeStep(nstep) !incremental time for each step.
	integer::nts=1
    
    type Stepinfo_tydef
        integer::matherstep=0
        logical::issteady=.true.
        integer::bctype=step,loadtype=step
        !LOADTYPE(BCTYPE):为荷载(位移边界)施加方式，
		!=1(ramp),表示步内荷载(位移边界)随时间线性施加，
		!=2(step(default))，表示步荷载(位移边界)在步初瞬间施加。
		!=-1(ReRamp) 表示步荷载(位移边界)随时间线性从大变小。
	end type
    type(Stepinfo_tydef),allocatable::stepinfo(:)
    integer::nstepinfo=1
	
!	type IniValue_tydef
!		real(kind=DPN),allocatable::v(:) !初值. initialvalue(nnode)
!	end type
!	type(IniValue_tydef)::InitialValue(MNDOF)
	
	
	!boundary condition data structure
	type bc_tydef
		integer::node,dof	!when body force is input, node equels to element	
		integer::sf=0,rtf=0 !step function for this load. 
		integer::isdead=0 !for =1,the condition is deactive in the current step.
		real(kind=DPN)::value=0
				
		!对于bc_disp,如果isdual==i(>0),则表示此自由度可能与出溢边界Nseep(i)重复，如果边界水头小于位置水头，则变为出溢边界。
		!对于Nseep, 如果isdual==i(>0)，则表示此自由度可能与水头边界BC_disp(i)重复，如果边界水头大于位置水头，则以水头边界为准，即水头边界的优先级大于出溢边界。
		integer::isdual=0
		integer::ssp_onepile=0 !只对SSP单元节点起作用，标示这个作用是否是作用在其中一根钢板桩上,而不两根都作用。
								!/=0,作用在单根钢板桩上，=0都作用。
	end type
	type(bc_tydef),allocatable::bc_disp(:),bc_load(:),bf(:),NSeep(:),IniValue(:),CFN(:)
	integer::bd_num=0,bl_num=0,bfnum=0,NumNSeep=0,Niniv=0,NCFN=0	
	real(kind=DPN),allocatable::iniValueDof(:) 
    
    type hinge_typef
        integer::element,node,dof=7 !单元号，节点号，自由度
		integer::newnode=0 !指向与节点Node为重合的节点node(newnode)。
    endtype
    type(hinge_typef),allocatable::FreeDOF(:)
    integer::Nfreedof=0
	
	integer,allocatable::IsBCChange(:)
		

	!material 
	type mat_tydef
		integer::type
		real(kind=DPN)::property(32)=0.0D0
		integer::sf(32)=0 !not considered yet.
		real(kind=DPN)::weight=0.0
!		real(kind=DPN)::dt !stress integration time step for viscoplasticity algorithm. 
		integer::FF1D(32)=0 !DEPENDENT FIELD FUNCTION,the default determined variable  is the centroid coordinates (Y)
		logical::isff=.false. ! whether the parameters are dependent on  the field function
		character(64)::name=""
	end type
	type(mat_tydef)::material(maximat)
	
	
	!solution control
	type solver_tydef
		integer::type=SLD !problem type,=SLD,solid;=SPG,seepage;=CPL,coupled.
		integer::solver=N_R !solution method, =-2, upper bound analysis,the default solver is N_R
		integer::bfgm=continuum  !body force generation method(stress update algorithm) if the INISTIFF method is applied.
		integer::niteration=100  !Maximum number of iterations allowed for each increment
		real(kind=DPN)::tolerance=0.001D0 !Convergence tolenance factor.
		real(kind=DPN)::ftol=1.D-6 !tolerance permitted for yiled criterion to be vilated
		real(kind=DPN)::force_tol=1.D-2 !tolerance permitted for unbalanced residual force to be vilated
		real(kind=DPN)::disp_tol=1.D-3 !tolerance permitted for residual displacement to be vilated
		integer::output=1 !1:output for mod(increments,output)=0 iteration
		integer::i2ncal=4  !method mapping variables in integration points to nodes
			!SHT=1,spr=2,AVG=3,EXP=4
		logical::issym=.true.
!		logical::issteady=.true. 
		logical::datapaking=.true. !.t.=point,.f.=block
		logical::ismg=.false. !just for limit analysis, if ismg=.true. minimize soil specific gravity, it demands that no nonzero boundary are applied.
		logical::islaverify=.false. !.true. to verify a soluction is whether a feasible one.
		logical::ispg=.false.  ! whether the job is just to read in result file and out put to tecplot.
		logical::isfc=.true. !whether the residual force criteria is implemented in judge of the convergence.
		!real(kind=DPN)::epsilon_spg=0.1 !for spg only. control the conductivity slope
!		integer::Para_spg=linear_spg !step_spg,linear_spg,unsat_spg.
									!if Para_spg=unsat_spg, van genuchten model is used. and 
									!alpha=material(element().mat).property(7)
									!n=material(element().mat).property(8)
		logical::ISFU=.false.  !For seepage problem, =yes, use factorization update to update the boundary condition change on the seepage face during iteration.
											!=NO, refactorization completely.
		logical::ismkl=.true.
        integer::mur=1
		real(kind=DPN)::BarfamilyScale=15.D0
        !parameter for line search
        INTEGER::ISLS=0
        INTEGER::NLS=10
        real(kind=DPN)::STOL=0.8D0,S0=0.D0
        
        !REAL(KIND=DPN),ALLOCATABLE::ETA(:),RATIO(:)
        
	end type
	type(solver_tydef)::solver_control
	
	type property_tydef
		character(64)::name=''
		real(kind=DPN)::value=0.0
		character(64)::cvalue=''	 !character value	
	end type
	type(property_tydef)::property(maxset) !one control line has MAXSET property value at most.
	integer::pro_num 

	type eset_tydef !for output
		integer::num=0 !the name of the set
		character(16)::Stype  !for tecplot FETRIANGLE, OR FEQUADRILATERAL
		integer::enums=0,enume=0 !the first and the last element number in the element() of the set. 
		integer::ec
		integer::et
        integer::system=0
		character(1024)::zonetitle=""
		character(64)::grouptitle=""
        
		!for bar ane beam element only.
		real(kind=DPN),allocatable::xyz_section(:,:) !单元集的统一的截面的四个角点的坐标，现假定一个单元集内的所有杆单元或梁单元的局部坐标一样。
		integer,allocatable::outorder(:) !输出后处理时，同一局部坐标下节点的输出顺序，与element.node2节点号对应。
        integer::noutorder=0
		integer,allocatable::elist(:,:) !单元集内的elist(2,noutorder)，目前假定一个节点最多有2个杆系单元。
    end type
	type(eset_tydef)::eset(maxset) !the maximum set number allowed is MAXSET.
	integer::neset=0  !set number in the model.	
	
	type ueset_type !for boundary conditions apply.
		integer::enum=0 !element number in the set
		character(32)::name=''
		integer,allocatable::element(:) !element index of the set
		integer::group=-1				
	end type
	type(ueset_type)::ueset(0:maxset) !ueset(0)=all elements in this model
	integer::nueset=1
	
	type unset_type
		integer::nnum=0 !node number in the set
		character(32)::name=''
		integer,allocatable::node(:) !node index of the set		
	end type
	type(unset_type)::unset(0:maxset) !unset(0)=all nodes in this model
	integer::nunset=1	
	
	!element class property
	type ECP_tydef
		integer::nshape,ngp,ndim,nnum  !number of the shape function,number of the gaussian integer point, space dimensions,number of nodes
		logical::isini=.false.  ! whether the element type is initialized or not.
		real(kind=DPN),allocatable::gp(:,:),weight(:) !gaussina point local coordinates and their corresponding weights
							!gp(ndim,ngp), the last nnum entries store the local coordinates in element nodal points.
		real(kind=DPN),allocatable::Lderiv(:,:,:)  ! Derivative of the shape functions with the local coordinates at gaussian points.
						  !Lderiv(nshape,ndim,ngp)
		real(kind=DPN),allocatable::Lshape(:,:)	! shape function value at gaussian points
							!Lshape(nshape,ngp)	
		real(kind=DPN),allocatable::expolating_Lshape(:,:) !for postprocedure only. storing the shape funciont values at nodes.
								!expolating_Lshape(nshape,nnum)
								!for cpe15,cpe15_spg, the matrix keeps the extrapolation matrix
		real(kind=DPN),allocatable::termval(:,:) !for exptrapolation, cpe15
	end type
	type(ECP_tydef)::ecp(maxiet)  !ecp(1:maxet), the class property of element(i) is stored in ecp(element(i).et)
	!element list sharing the same vertex, the mid- and insided nodes are excluded
	type SPR_tydef
		integer::elist(10)
		integer::nelist=0	!the element number sharing the vertex
		integer::p=0		!the order of the extropolating polynomial
		integer::item=0	!the number of the polynomail item.
		integer::nsc=0	!the sample point number of superconvergence
		logical::ispatch=.false. !wether the node is the centre of the patch.
		real(kind=DPN),allocatable::polynomial(:,:) !the interpolating
		real(kind=DPN),allocatable::A(:,:)  !the A 
		integer,allocatable::ipvt(:) !the pivoting information
		real(kind=DPN)::dxmax=-1e15,dymax=-1e15  !the max distance in x and y directions of the patch
					! polynomials of each superconvergent sample point of the patch
	end type
	type(SPR_tydef),allocatable::SPRLIST(:)
	
	type geostatic_tydef
		logical::isgeo=.false.
		integer::method=1 ! cal=1,ko=2, the ko method only for horizontal ground surface
											!horizontal soil layer
		integer::nsoil=1 !the number of soil layers
		real(kind=DPN),allocatable::KO(:),weight(:),height(:)
	end type
	type(geostatic_tydef)::geostatic

	!output variables
	type outvar_tydef
		character(32)::name=''
		integer::value=0	!>0, variable output is required.
		logical::iscentre=.false. !location, nodes or centroid of element.
		integer::system=0	!reference systerm,the default system is the globel sysytem
								!if system=-999, then the local system is a cylindrical system whose origin is along 
								!the central line of the cylinder.
								!if system=-9999,then the local system is a spherical syystem whose origin is located
								!at the center of the sphere
	end type
	type(outvar_tydef)::outvar(100)	
	integer::vo(100)=0,nvo=0
	
	type coordinate_tydef !global to local system transformation matrix 
		real(kind=DPN)::c(3,3)=0 !c(i,j)=cos(ei,Ej),ei and Ej are base vectors for new and old coordinates.
	end type	
	type(coordinate_tydef),allocatable::coordinate(:) !coordinate(0) is the whole coordinate system.
	integer::ncoord=0
    
	
	!注意，master点上的mdof自由度上目前不能施加位移边界条件，这时输入时变换一个slave和master
	type slave_master_node_pairtydef		
		integer::slave=0,sdof=0		
		integer::master=0,mdof=0
		integer::nmbl=0 !作用在master节点上的荷载个数,目前最多允许10个。
		integer::mbl(10)=0
		integer::pe=0 !对应的罚单元
		real(kind=DPN)::interforce=0.0d0,load=0.0d0
		real(kind=DPN)::aff=0.0d0 !allowablefrictionforce
	end type
	type(slave_master_node_pairtydef),allocatable::smnp(:)
	integer::nsmnp=0
	
	type out_data_typdef
        integer::nnode=0
        integer,allocatable::node(:)        
    end type
    type(out_data_typdef),allocatable::DataPoint(:)
    integer::NDataPoint=0
	

	
    !type rcd_set_tydef
    !    integer::rcd
    !    integer::enums,enume
    !end type
    !type(rcd_set_tydef),allocatable::rcdset(:)
    !integer::nrcdset=0
    !integer,allocatable::rcd(:,:)
    !integer::nrcd=0

	
	character(1024)::title,resultfile,resultfile1,resultfile2,resultfile3,resultfile21,resultfile22,EXCAMSGFILE,EXCAB_BEAMRES_FILE,&
					EXCAB_STRURES_FILE
	INTEGER::DATAPOINT_UNIT=29
	integer::datapacking=1	!=1,point format:{x1,y1,z1},{x2,y2,z2},..., . (Default Format)
						 != 2, block format, {x1,x2,...},{y1,y2,...},{z1,z2,...}
	integer::ndimension=2	!nodal dimension,
						!=1, input x
						!=2, input x and y
						!=3 input x,y and z
							
	integer::ndof=0 !total dof number
	integer,allocatable::bw(:) 	!bw(i): firstly, it is the column number of the most left entry in the i row. and later, it is the bandwidth of the total matrix
														!!for default solver, finally it stores the diagonal address in the total stiffness matrix
	
	integer::bwmax=0 !the maximum value of the band width. 
	real(kind=DPN),allocatable::load(:),Tload(:),km(:),tdisp(:),bfload(:),stepload(:)	!km(:):Lower  trianglar part of total stiffness matrix(including diagonal elements)
	real(kind=DPN),allocatable::tdispInLS(:) ! Total displacement in a local system.
	real(kind=DPN),allocatable::NI_NodalForce(:) !由单元积分而得的节点力。
	real(kind=DPN),allocatable::Tstepdis(:,:) !TstepDisp(ndof,nstep):各步结束时的各自由度的量。 
	!additioinal variables defined when the linear system is unsymmetric.
!	real(kind=DPN),allocatable::ukm(:)	!ukm(:):Upper trianglar part of total stiffness matrix(including diagonal elements,but set equel to 0)
!	integer,allocatable::ubw(:)
	
!	real(kind=DPN),allocatable::a(:) !nonzero elments in km(:) and ukm(:)	

	integer::nnz=0
	integer,allocatable::irow(:),jcol(:),Lmre(:),adrn(:) !Lmre(i): the column number of the most rigth entry in the i row.
	integer,allocatable::ROWINDEX(:) !rowindex:总刚中每一行第一个非零元素在总刚数组中的位置;
											!bw: 一开始为总刚中每一行第一个非零元素在总刚中的列号，最后为总刚中每一行最后一个非零元素在总刚数组中的位置;
											!Lmre:总刚中每一行最后一个非零元素在总刚中的列号。
											!值得注意的是：在default solver中，总刚含有零元（存在于每行第一个非零元和最后一个非零元之间），而在mkl或坐标存储格式中，总刚不含零元。
											!adrn(i):在default solver中的总刚数组中非零元 i 在mkl格式总刚数组的位置。
	
	
	real(kind=DPN),allocatable::DIAGLKM(:) !STORED DIAGONAL ELEMENT OF THE KM BEFORE FACTORIZATION FOR FACTOR UPDATING.
	integer,allocatable::diaglkmloc(:) !总刚中对角线元素在总刚数组中的位置。

	!one dimensional linear field function
	real(kind=DPN)::LF1D(0:maxilf,2)  !LF1D(:,1)=k,LF1D(:,2)=c. then y=k*x+c

!	integer::NLF1D=0 

	!additional variables for upper bound analysis
	integer::ncons=0 !number of constraints imposed by elements
	integer::nuvar=0 !uncontraint variables in linear programming
	integer::nzone_tec=0 !the number of zone in output file in tecplot format.
	integer::varsharezone_tec=0 !the zone number whose variables are shared with others in output file in tecplot format.
	
	real(kind=DPN)::NormL=0.0
	
	real(kind=DPN)::minNPH=1e20
	integer::isref_spg=0 !是否重新分解矩阵
	real(kind=DPN)::eps1=1e20,eps2=1e20
	real(kind=DPN)::Origin_Sys_cylinder(3)=0.0  !in the order of x,y and z. the default value is 0.
	real(kind=DPN)::Qinput=0.0d0,Qstored=0.0d0,Qstorted_ini=0.0d0 !质量守恒 
	
	real(kind=DPN)::BARFAMILY_DIAGRAM_SCALE(12)=0.0D0 !先存绝对最大值，后存画图放大系数，DISX,DISY,DISZ,RX,RY,RZ,FX,FY,FZ,MX,MY,MZ
	real(kind=DPN)::barfamily_minxyz(3)=1.0d20,barfamily_maxxyz(3)=-1.0d20 !
    INTEGER::ISEXCA2D=0,ISHBEAM=0
	REAL(KIND=DPN)::GA=10.0D0
    
   
    
    contains
    
    

    
	function pi()
		real(kind=DPN)::pi
		pi=1
		pi=datan(pi)*4	
	end function
	
	real(DPN) function matproperty(imat,ipara,istep)
	
		implicit none
		integer,intent(in)::imat,ipara,istep
		matproperty=material(imat).property(ipara)*sf(material(imat).sf(ipara)).factor(istep)
	endfunction
	!
	real(kind=DPN) function materialfun(Fid,x)
		integer::fid
		real(kind=DPN)::x	
			
		materialfun=LF1D(FID,1)*X+LF1D(FID,2)
	end function

	FUNCTION csproduct(a1,a2) RESULT(maxoa)
	!
	! This function returns the dyadic product of two arrays
	! 
		 IMPLICIT NONE    
		 real(kind=DPN),INTENT(IN)::a1(:),a2(:)
		 real(kind=DPN)::maxoa(size(a1),size(a2))
		 INTEGER::nrow,i,j,ncol
		 
		 nrow=UBOUND(a1,1)
		 ncol=UBOUND(a2,1)
		 DO i=1,nrow
			DO j=1,ncol
				maxoa(i,j)=a1(i)*a2(j)
			ENDDO
		ENDDO
		RETURN
    END FUNCTION csproduct
    
FUNCTION determinant(jac)RESULT(det)
!
! This function returns the determinant of a 1x1, 2x2 or 3x3
! Jacobian matrix.
!
 IMPLICIT NONE    
 INTEGER,PARAMETER::iwp=SELECTED_REAL_KIND(15)
 REAL(iwp),INTENT(IN)::jac(:,:)
 REAL(iwp)::det
 INTEGER::it 
 it=UBOUND(jac,1)  
 SELECT CASE(it)
 CASE(1)
   det=1.0_iwp
 CASE(2)
   det=jac(1,1)*jac(2,2)-jac(1,2)*jac(2,1)
 CASE(3)
   det=jac(1,1)*(jac(2,2)*jac(3,3)-jac(3,2)*jac(2,3))
   det=det-jac(1,2)*(jac(2,1)*jac(3,3)-jac(3,1)*jac(2,3))
   det=det+jac(1,3)*(jac(2,1)*jac(3,2)-jac(3,1)*jac(2,2))
 CASE DEFAULT
   WRITE(*,*)' wrong dimension for Jacobian matrix'
 END SELECT
RETURN
END FUNCTION determinant 
    
end module

    
    

MODULE SOLVERLIB

    USE solverds
    
    INTERFACE
        subroutine enlarge_bc(bc,nbc,enbc,ibc)
            USE solverds
	        integer,intent(in)::enbc
	        type(bc_tydef),intent(in out),allocatable::bc(:)
	        integer,intent(out)::ibc
	        integer,intent(in out)::nbc
	        !type(bc_tydef),ALLOCATABLE::bc1(:)
        ENDSUBROUTINE
        
        subroutine enlarge_element(EL,NEL,enel,iel)
        !扩大EL数组,同时update总的单元数NEL=NEL+enel
        !Enel:扩大的单元个数
        !iel,:扩容部分的起位
            USE solverds
	        integer,intent(in)::enel
            INTEGER,INTENT(IN OUT)::NEL
            type(element_tydef),INTENT(IN OUT),ALLOCATABLE::EL(:)
	        integer,intent(out)::iel        
        ENDSUBROUTINE

        subroutine enlarge_node(EL,NEL,enel,iel)
        !扩大EL数组,同时update总的单元数NEL=NEL+enel
        !Enel:扩大的单元个数
        !iel,:扩容部分的起位
            USE solverds
	        integer,intent(in)::enel
            INTEGER,INTENT(IN OUT)::NEL
            type(node_tydef),INTENT(IN OUT),ALLOCATABLE::EL(:)
	        integer,intent(out)::iel        
        ENDSUBROUTINE		
		
        SUBROUTINE invert(matrix)
            !
            ! This subroutine inverts a small square matrix onto itself.
            !
             IMPLICIT NONE
             INTEGER,PARAMETER::iwp=SELECTED_REAL_KIND(15)
             REAL(iwp),INTENT(IN OUT)::matrix(:,:)

        ENDSUBROUTINE  
    ENDINTERFACE
    
    CONTAINS
    
    

    ENDMODULE

    
subroutine enlarge_bc(bc,nbc,enbc,ibc)
    !扩大bc数组,同时update总的单元数NBC=NBC+enBC
    !EnBC:扩大的单元个数
    !iBC:扩容部分的初始起位
	    use solverds	
	    implicit none
	    integer,intent(in)::enbc
	    type(bc_tydef),intent(in out),allocatable::bc(:)
	    integer,intent(out)::ibc
	    integer,intent(in out)::nbc
	    type(bc_tydef),ALLOCATABLE::bc1(:)
	
	    allocate(bc1(nbc+enbc))
	    bc1(1:nbc)=bc
	    if(allocated(bc)) deallocate(bc)
	    ibc=nbc+1
	    nbc=nbc+enbc
	    !nbc=jbc
	    allocate(bc,source=bc1)
	    !element=element1
	    deallocate(bc1)
	
    endsubroutine
    
subroutine enlarge_element(EL,NEL,enel,iel)
!扩大EL数组,同时update总的单元数NEL=NEL+enel
!Enel:扩大的单元个数
!iel,:扩容部分的起位
	use solverds	
	implicit none
	integer,intent(in)::enel
    INTEGER,INTENT(IN OUT)::NEL
    type(element_tydef),INTENT(IN OUT),ALLOCATABLE::EL(:)
	integer,intent(out)::iel
	type(element_tydef),ALLOCATABLE::element1(:)
	
	IF(ENEL<1) RETURN
	
	allocate(element1(NEL+enel))
	element1(1:NEL)=EL
	if(allocated(EL)) deallocate(EL)
	iel=NEL+1
	NEL=NEL+enel	
	allocate(EL,SOURCE=ELEMENT1)
	deallocate(element1)
	
endsubroutine    

subroutine enlarge_node(EL,NEL,enel,iel)
!扩大EL数组,同时update总的单元数NEL=NEL+enel
!Enel:扩大的单元个数
!iel,:扩容部分的起位
	use solverds	
	implicit none
	integer,intent(in)::enel
    INTEGER,INTENT(IN OUT)::NEL
    type(node_tydef),INTENT(IN OUT),ALLOCATABLE::EL(:)
	integer,intent(out)::iel
	type(node_tydef),ALLOCATABLE::element1(:)
	
	IF(ENEL<1) RETURN
	
	allocate(element1(NEL+enel))
	element1(1:NEL)=EL
	if(allocated(EL)) deallocate(EL)
	iel=NEL+1
	NEL=NEL+enel	
	allocate(EL,SOURCE=ELEMENT1)
	deallocate(element1)
	
endsubroutine


    
SUBROUTINE invert(matrix)
!
! This subroutine inverts a small square matrix onto itself.
!
 IMPLICIT NONE
 INTEGER,PARAMETER::iwp=SELECTED_REAL_KIND(15)
 REAL(iwp),INTENT(IN OUT)::matrix(:,:)
 REAL(iwp)::det,j11,j12,j13,j21,j22,j23,j31,j32,j33,con
 INTEGER::ndim,i,k
 ndim=UBOUND(matrix,1)
 IF(ndim==2)THEN
   det=matrix(1,1)*matrix(2,2)-matrix(1,2)*matrix(2,1)
   j11=matrix(1,1)
   matrix(1,1)=matrix(2,2)
   matrix(2,2)=j11
   matrix(1,2)=-matrix(1,2)
   matrix(2,1)=-matrix(2,1)
   matrix=matrix/det
 ELSE IF(ndim==3)THEN
   det=matrix(1,1)*(matrix(2,2)*matrix(3,3)-matrix(3,2)*matrix(2,3))
   det=det-matrix(1,2)*(matrix(2,1)*matrix(3,3)-matrix(3,1)*matrix(2,3))
   det=det+matrix(1,3)*(matrix(2,1)*matrix(3,2)-matrix(3,1)*matrix(2,2))
   j11=matrix(2,2)*matrix(3,3)-matrix(3,2)*matrix(2,3)
   j21=-matrix(2,1)*matrix(3,3)+matrix(3,1)*matrix(2,3)
   j31=matrix(2,1)*matrix(3,2)-matrix(3,1)*matrix(2,2)
   j12=-matrix(1,2)*matrix(3,3)+matrix(3,2)*matrix(1,3)
   j22=matrix(1,1)*matrix(3,3)-matrix(3,1)*matrix(1,3)
   j32=-matrix(1,1)*matrix(3,2)+matrix(3,1)*matrix(1,2)
   j13=matrix(1,2)*matrix(2,3)-matrix(2,2)*matrix(1,3)
   j23=-matrix(1,1)*matrix(2,3)+matrix(2,1)*matrix(1,3)
   j33=matrix(1,1)*matrix(2,2)-matrix(2,1)*matrix(1,2)
   matrix(1,1)=j11
   matrix(1,2)=j12
   matrix(1,3)=j13
   matrix(2,1)=j21
   matrix(2,2)=j22
   matrix(2,3)=j23
   matrix(3,1)=j31
   matrix(3,2)=j32
   matrix(3,3)=j33
   matrix=matrix/det
 ELSE
   DO k=1,ndim
     con=matrix(k,k)
     matrix(k,k)=1.0_iwp
     matrix(k,:)=matrix(k,:)/con
     DO i=1,ndim
       IF(i/=k)THEN
         con=matrix(i,k)
         matrix(i,k)=0.0_iwp
         matrix(i,:)=matrix(i,:)-matrix(k,:)*con
       END IF
     END DO
   END DO
 END IF
RETURN
END SUBROUTINE invert    
