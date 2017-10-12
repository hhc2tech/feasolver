!---------------------------------------------------------------------------

module function_plotter
use opengl_gl
use opengl_glut
use view_modifier
!use solverds
!use IndexColor
use MESHGEO
implicit none
!private
!public :: display,menu_handler,make_menu,CONTOUR_PLOT_VARIABLE,VECTOR_PLOT_GROUP
private::SET_VARIABLE_SHOW,SET_VECTOR_PLOT_GROUP
! symbolic constants

!contour
integer,parameter:: Contour_surfsolid_toggle = 1, &
                    Contour_Line_toggle = 2, &
                    Contour_Densify=3,&
                    Contour_Sparsify=4,&
                    Contour_In_DeformedMesh=5
integer, parameter :: black_contour = 1, &
                      rainbow_contour = 2
integer, parameter :: white_surface = 1, &
                      red_surface = 2, &
                      rainbow_surface = 3 ,&
                      transparency=4
                      
real(8),public::Scale_Contour_Num=1.0
logical,public::istransparency=.false.,IsContour_In_DeformedMesh=.false. 

type contour_bar_tydef
	INTEGER::IVARPLOT=0
    integer :: nfrac,nval
    real(GLDOUBLE),allocatable :: val(:)
    real(GLFLOAT),allocatable::COLOR(:,:)
    character(128)::TITLE
endtype
type(contour_bar_tydef)::ContourBar

TYPE ISOLINE_TYDEF
    INTEGER::NV=0,NE=0,NTRI=0
    REAL(8)::VAL
    REAL(8),ALLOCATABLE::V(:,:)
    INTEGER,ALLOCATABLE::EDGE(:,:),TRI(:,:)    
END TYPE
TYPE(ISOLINE_TYDEF),ALLOCATABLE::ISOLINE(:)
INTEGER::NISOLINE

TYPE SLICE_TYDEF
	INTEGER::IVARPLOT=0
    INTEGER::PLANE=-1
    INTEGER::NV=0,NTRI=0,NISOLINE=0,NBCE=0 
    REAL(8)::X=0
    REAL(8),ALLOCATABLE::V(:,:),VAL(:,:)
    INTEGER,ALLOCATABLE::TRI(:,:),BCEDGE(:,:)
    TYPE(ISOLINE_TYDEF),ALLOCATABLE::ISOLINE(:)
END TYPE
TYPE(SLICE_TYDEF)::SLICE(30)
INTEGER::NSLICE=0

INTEGER::IVO(3)=0 !FOR VECTOR PAIR LOCATION IN NODALQ
INTEGER::IEL_STREAMLINE=0 !当前积分点所在的单元
INTEGER,PARAMETER::streamline_location_click=1,Plot_streamline_CLICK=2
LOGICAL::isstreamlineinitialized=.false.
TYPE STREAMLINE_TYDEF
    INTEGER::NV=0
    REAL(8)::PTstart(3)
    REAL(8),ALLOCATABLE::V(:,:),DT(:)
ENDTYPE
TYPE(STREAMLINE_TYDEF)::STREAMLINE(100)
INTEGER::NSTREAMLINE=0

!vector
TYPE VECTOR_PLOT_TYDEF
	INTEGER::GROUP
	REAL(8)::SCALE=1.0D0
	REAL(8),POINTER::VEC(:,:)=>NULL()
ENDTYPE

INTEGER,PARAMETER:: VECTOR_GROUP_DIS=1,&
                    VECTOR_GROUP_SEEPAGE_VEC=2,&
                    VECTOR_GROUP_SEEPAGE_GRAD=3,&
                    VECTOR_GROUP_SFR=4
integer,parameter::Vector_toggle= 1, &
                   Vector_lengthen=2,&
                   Vector_shorten=3                   
                   
real(8),public::Scale_Vector_Len=1.0,VabsMax,VabsMin,Vscale                    
character(128)::VectorPairName
!model
integer, parameter :: surfgrid_toggle = 1, &
                      quit_selected = 4,&
                      DeformedMesh=5,&
                      Enlarge_Scale_DeformedMesh=6,&
                      Minify_Scale_DeformedMesh=7,&
					  Edge_toggle=8,&
					  Node_toggle=9,&
					  probe_selected=10
					  
					  
!NODALVALUE
INTEGER,PARAMETER::SHOWNODALVALUE_TOGGLE=1
INTEGER::SHOW_NODAL_VALUE=0
LOGICAL::ISSHOWNODALVALUE=.FALSE.,isProbestate=.false.
                      
logical::IsDeformedMesh=.false.,show_edge=.false.,show_node=.false.                     
real(8)::Scale_Deformed_Grid=1.d0


!SLICE
INTEGER,PARAMETER::SLICE_LOCATION_CLICK=1,PLOTSLICESURFACE_CLICK=2,PLOTSLICEISOLINE_CLICK=3,&
				PLOTSLICE_CLICK=4
	

!TYPE SLICE_TYDEF
!    
!
!ENDTYPE

integer, parameter :: set_nx = 1, &
                      set_ny = 2, &
                      set_ncontour = 3, &
                      set_contour_val = 4, &
                      set_xrange = 5, &
                      set_yrange = 6, &
                      reset_params = 7



! Default initial settings

integer,parameter :: init_ngridx = 40, &
                      init_ngridy = 40, &                      
                      init_contour_color = black_contour, &
                      init_surface_color = rainbow_surface

real(GLDOUBLE), parameter :: init_minx = 0.0_GLDOUBLE, &
                             init_maxx = 1.0_GLDOUBLE, &
                             init_miny = 0.0_GLDOUBLE, &
                             init_maxy = 1.0_GLDOUBLE

logical, parameter :: init_draw_surface_grid = .false., &
                      init_draw_surface_solid = .true., &
                      init_draw_contour = .true.


! Current settings

integer :: ngridx = init_ngridx, &
           ngridy = init_ngridy, &
           num_contour = 20, &
           contour_color = init_contour_color, &
           surface_color = init_surface_color,&
           init_num_contour = 20

!real(GLDOUBLE) :: minx = init_minx, &
!                  maxx = init_maxx, &
!                  miny = init_miny, &
!                  maxy = init_maxy, &
!                  minz = 0.0_GLDOUBLE, &
!                  maxz = 0.0_GLDOUBLE

logical :: draw_surface_grid = init_draw_surface_grid, &
           draw_surface_solid = init_draw_surface_solid, &
           draw_contour = init_draw_contour, &
           contour_values_given = .false.,&
           IsDrawVector=.false.,&
		   IsPlotSliceSurface=.false.,&
		   isPLotSliceIsoLIne=.false.,&
           isPlotStreamLine=.false.,&
		   ISPLOTSLICE=.FALSE.

real(GLDOUBLE), allocatable :: actual_contours(:)
real(GLDOUBLE) :: minv,maxv

integer::CONTOUR_PLOT_VARIABLE=0,VECTOR_PLOT_GROUP=VECTOR_GROUP_DIS,SLICE_PLOT_VARIABLE=0

integer,parameter,public::ContourList=1,&
                          VectorList=2,&
                          GridList=3,&
						  ContourLineList=4,&
                          ProbeValueList=5,&
						  SLICELIST=6,&
                          StreamLineList=7,&
						  STEPSTATUSLIST=8
                          
                       

!real(GLFLOAT) :: red(4) = (/1.0,0.0,0.0,1.0/), &
!                 black(4) = (/0.0,0.0,0.0,1.0/), &
!                 white(4) = (/1.0,1.0,1.0,1.0/),&
!                 GRAY(4)=(/0.82745098,0.82745098,0.82745098,1.0/) 


TYPE TIMESTEPINFO_TYDEF
    INTEGER::ISTEP=1,NSTEP=1
    REAL(8),ALLOCATABLE::TIME(:)
	INTEGER,ALLOCATABLE::CALSTEP(:) !当前步对应的计算步，注意，计算步与绘图步往往不一致。
    LOGICAL::ISSHOWN=.TRUE.
	REAL(8)::VSCALE(4)=1.0D0,VMIN(4),VMAX(4)
    CHARACTER(256)::INFO=''
    CONTAINS
    PROCEDURE::INITIALIZE=>STEP_INITIALIZE
    PROCEDURE::UPDATE=>STEP_UPDATE
	
ENDTYPE
TYPE(TIMESTEPINFO_TYDEF),PUBLIC::STEPPLOT				 

contains

SUBROUTINE STEP_INITIALIZE(STEPINFO,ISTEP,NSTEP,TIME,CALSTEP)
    IMPLICIT NONE
    CLASS(TIMESTEPINFO_TYDEF),INTENT(in out):: STEPINFO
    INTEGER,INTENT(IN)::ISTEP,NSTEP,CALSTEP(NSTEP)
    REAL(8),INTENT(IN)::TIME(NSTEP)
	REAL(8),ALLOCATABLE::VEC1(:,:,:)
	INTEGER::I
    
	
	
	
    STEPINFO.ISTEP=ISTEP
    STEPINFO.NSTEP=NSTEP
    ALLOCATE(STEPINFO.TIME,SOURCE=TIME)
	ALLOCATE(STEPINFO.CALSTEP,SOURCE=CALSTEP)
	ALLOCATE(VEC1(3,NNUM,NSTEP))
	

	
	!SET UP VECSCALE
	IF(OUTVAR(DISX).VALUE>0.AND.OUTVAR(DISY).VALUE>0) THEN
		DO I=1,STEPPLOT.NSTEP
			VEC1(1,:,I)=NODALQ(:,OUTVAR(DISX).IVO,I)
			VEC1(2,:,I)=NODALQ(:,OUTVAR(DISY).IVO,I)
			IF(NDIMENSION>2) THEN
				VEC1(3,:,I)=NODALQ(:,OUTVAR(DISZ).IVO,I)
			ELSE
				VEC1(3,:,I)=0
			ENDIF
		ENDDO
		STEPINFO.VMAX(1)=MAX(MAXVAL(NORM2(VEC1,DIM=1)),1.0E-8)
		STEPINFO.VMIN(1)=MINVAL(NORM2(VEC1,DIM=1))
		STEPINFO.VSCALE(1)=modelr/40./STEPINFO.VMAX(1)
        
    ENDIF
	
	IF(OUTVAR(VX).VALUE>0.AND.OUTVAR(VY).VALUE>0) THEN
		DO I=1,STEPPLOT.NSTEP
			VEC1(1,:,I)=NODALQ(:,OUTVAR(VX).IVO,I)
			VEC1(2,:,I)=NODALQ(:,OUTVAR(VY).IVO,I)
			IF(NDIMENSION>2) THEN
				VEC1(3,:,I)=NODALQ(:,OUTVAR(VZ).IVO,I)
			ELSE
				VEC1(3,:,I)=0
			ENDIF
		ENDDO
		STEPINFO.VMAX(2)=MAX(MAXVAL(NORM2(VEC1,DIM=1)),1.0E-8)
		STEPINFO.VMIN(2)=MINVAL(NORM2(VEC1,DIM=1))
		STEPINFO.VSCALE(2)=modelr/40./STEPINFO.VMAX(2)
        
    ENDIF
    
	IF(OUTVAR(GRADX).VALUE>0.AND.OUTVAR(GRADY).VALUE>0) THEN
		DO I=1,STEPPLOT.NSTEP
			VEC1(1,:,I)=NODALQ(:,OUTVAR(GRADX).IVO,I)
			VEC1(2,:,I)=NODALQ(:,OUTVAR(GRADY).IVO,I)
			IF(NDIMENSION>2) THEN
				VEC1(3,:,I)=NODALQ(:,OUTVAR(GRADZ).IVO,I)
			ELSE
				VEC1(3,:,I)=0
			ENDIF
		ENDDO
		
		STEPINFO.VMAX(3)=MAX(MAXVAL(NORM2(VEC1,DIM=1)),1.0E-8)
		STEPINFO.VMIN(3)=MINVAL(NORM2(VEC1,DIM=1))
		STEPINFO.VSCALE(3)=modelr/40./STEPINFO.VMAX(3)
        
    ENDIF
	
	IF(OUTVAR(SFR_SFRX).VALUE>0.AND.OUTVAR(SFR_SFRY).VALUE>0) THEN
		DO I=1,STEPPLOT.NSTEP
			VEC1(1,:,I)=NODALQ(:,OUTVAR(SFR_SFRX).IVO,I)
			VEC1(2,:,I)=NODALQ(:,OUTVAR(SFR_SFRY).IVO,I)
			VEC1(3,:,I)=0
		ENDDO

		STEPINFO.VMAX(4)=MAX(MAXVAL(NORM2(VEC1,DIM=1)),1.0E-8)
		STEPINFO.VMIN(4)=MINVAL(NORM2(VEC1,DIM=1))
		STEPINFO.VSCALE(4)=modelr/40./STEPINFO.VMAX(4)
        
    ENDIF
	

	
	
	DEALLOCATE(VEC1)
    
ENDSUBROUTINE

SUBROUTINE STEP_UPDATE(STEPINFO)
    IMPLICIT NONE
    CLASS(TIMESTEPINFO_TYDEF),INTENT(in out):: STEPINFO
    CHARACTER(16)::CWORD1,CWORD2,CWORD3,CWORD4
    REAL(8)::POS1(2)
    INTEGER::I
	
    WRITE(CWORD1,*) STEPINFO.ISTEP
    WRITE(CWORD2,*) STEPINFO.NSTEP
    WRITE(CWORD3,'(F10.5)') STEPINFO.TIME(STEPINFO.ISTEP)
    WRITE(CWORD4,'(F10.5)') STEPINFO.TIME(STEPINFO.NSTEP)
    
    STEPINFO.info='ISTEP/NSTEP='//TRIM(ADJUSTL(CWORD1))//'/'//TRIM(ADJUSTL(CWORD2))//',ITIME/NTIME=' &    
              //TRIM(ADJUSTL(CWORD3))//'/'//TRIM(ADJUSTL(CWORD4))
	POS1(1)=0.25;POS1(2)=0.05
	CALL SHOW_MTEXT(STEPINFO.info,1,POS1,BLACK,STEPSTATUSLIST)		  
    !INFO.QKEY=.TRUE.;INFO.ISNEEDINPUT=.FALSE.;INFO.COLOR=GREEN
    
	!ACTIVATE FACE AND EDGE
	IF(.NOT.ALLOCATED(VISDEAD)) ALLOCATE(VISDEAD(NNUM))
	FACE.ISDEAD=1;EDGE.ISDEAD=1;TET.ISDEAD=1;VISDEAD=1	
	DO I=1,NTET
		IF(SF(TET(I).SF).FACTOR(STEPINFO.CALSTEP(STEPINFO.ISTEP))==1) THEN
			TET(I).ISDEAD=0
			FACE(TET(I).F(1:TET(I).NF)).ISDEAD=0
			EDGE(TET(I).E(1:TET(I).NE)).ISDEAD=0
			VISDEAD(TET(I).V(1:TET(I).NV))=0
		ENDIF	
	ENDDO

	DO I=1,ENUM
		IF(SF(ELEMENT(I).SF).FACTOR(STEPINFO.CALSTEP(STEPINFO.ISTEP))==1) THEN			
			MFACE(ELEMENT(I).FACE(1:ELEMENT(I).NFACE)).ISDEAD=0
			MEDGE(ELEMENT(I).EDGE(1:ELEMENT(I).NEDGE)).ISDEAD=0			
		ENDIF	
	ENDDO
	
    IF(IsDrawVector) THEN
		CALL VEC_PLOT_DATA()
		CALL DrawVector()
	ENDIF
	
    IF(draw_surface_solid) CALL DrawSurfaceContour()
	IF(draw_contour) CALL DrawLineContour()
	
	IF(ISPLOTSLICE) THEN
		CALL GEN_SLICE_SURFACE_DATA()
		CALL GEN_SLICE_ISOLINE_DATA()
		CALL SLICEPLOT()
	ENDIF
    
	IF(isPlotStreamLine) THEN
		
		CALL streamline_update()
	
	ENDIF
    
ENDSUBROUTINE


subroutine display

! This gets called when the display needs to be redrawn

call reset_view

call glClear(ior(GL_COLOR_BUFFER_BIT,GL_DEPTH_BUFFER_BIT))
if(glIsList(StepStatusList)) call glCallList(StepStatusList)
if(draw_surface_solid.AND.glIsList(ContourList)) call glCallList(ContourList)
if(draw_contour.AND.glIsList(ContourLineList)) call glCallList(ContourLineList)
if(glIsList(VectorList)) call glCallList(VectorList)
if(glIsList(GridList)) call glCallList(GridList)
if(isProbeState.AND.glIsList(ProbeValuelist)) call glCallList(ProbeValuelist)
if(glIsList(slicelist).AND.ISPLOTSLICE) call glcalllist(slicelist)
if(ISPLOTSTREAMLINE.AND.glIsList(STREAMLINElist)) call glcalllist(STREAMLINElist)
call drawAxes()
if(IsDrawVector) call drawVectorLegend2(VabsMax,VabsMin,Vscale,VectorPairName)
if ((surface_color==rainbow_surface.and.(draw_surface_solid.or.draw_Contour)).OR.ISPLOTSLICESURFACE) then
    call Color_Bar()
endif
IF(ISSHOWNODALVALUE) CALL DRAW_NADAL_VALUE()
IF(LEN_TRIM(ADJUSTL(INFO.STR))>0) CALL SHOWINFO(INFO.COLOR)
IF(LINE_TEMP.SHOW) CALL LINE_TEMP.DRAW()

call glutSwapBuffers

return
end subroutine display



function normcrossprod(x,y,z)
real(glfloat), dimension(3) :: normcrossprod
real(gldouble), dimension(3), intent(in) :: x,y,z
real(glfloat) :: t1(3),t2(3),norm
t1(1) = x(2) - x(1)
t1(2) = y(2) - y(1)
t1(3) = z(2) - z(1)
t2(1) = x(3) - x(1)
t2(2) = y(3) - y(1)
t2(3) = z(3) - z(1)
normcrossprod(1) = t1(2)*t2(3) - t1(3)*t2(2)
normcrossprod(2) = t1(3)*t2(1) - t1(1)*t2(3)
normcrossprod(3) = t1(1)*t2(2) - t1(2)*t2(1)
norm = sqrt(dot_product(normcrossprod,normcrossprod))
if (norm /= 0._glfloat) normcrossprod = normcrossprod/norm
end function normcrossprod

subroutine menu_handler(selection)

integer(kind=glcint), intent(in out) :: selection

select case (selection)

case(probe_selected)
	isProbeState=.not.isProbestate
    if(.not.isProbeState) call glutSetCursor(GLUT_CURSOR_LEFT_ARROW)
    
case (quit_selected)
   stop

end select

return
end subroutine menu_handler

subroutine SLICE_handler(selection)
    implicit none
    integer(kind=glcint), intent(in out) :: selection

    select case (selection)

    case(slice_location_click)
	    !isPickforslice=.true.
		!CALL GETSLICELOCATION()
        CALL INPUTSLICELOCATION()
    CASE(PLOTSLICESURFACE_CLICK)
		ISPLOTSLICESURFACE=.NOT.ISPLOTSLICESURFACE
    CASE(PLOTSLICEISOLINE_CLICK)
		ISPLOTSLICEISOLINE=.NOT.ISPLOTSLICEISOLINE
	CASE(PLOTSLICE_CLICK)
		ISPLOTSLICE=.NOT.ISPLOTSLICE
        
		
    end select
    
	call SLICEPLOT()
	
end subroutine

subroutine streamline_handler(selection)
    implicit none
    integer(kind=glcint), intent(in out) :: selection

    select case (selection)

    case(streamline_location_click)
        isPickforstreamline=.true.
        isPlotStreamLine=.true.
        info.qkey=.true.
        call glutSetCursor(GLUT_CURSOR_CROSSHAIR)  
    CASE(Plot_streamline_CLICK)
		isPlotStreamLine=.not.isPlotStreamLine
  !  CASE(PLOTSLICEISOLINE_CLICK)
		!ISPLOTSLICEISOLINE=.NOT.ISPLOTSLICEISOLINE
        
		
    end select
    
    !CALL STREAMLINE_INI()
	!call SLICEPLOT()
	
end subroutine

SUBROUTINE set_variable_show(VALUE)
integer(kind=glcint), intent(in out) :: value 

CONTOUR_PLOT_VARIABLE=VALUE
IF(CONTOURBAR.IVARPLOT/=outvar(CONTOUR_PLOT_VARIABLE).ivo) call initialize_contourplot(outvar(CONTOUR_PLOT_VARIABLE).ivo)
CALL DrawSurfaceContour()
call DrawLineContour()

RETURN
END SUBROUTINE

SUBROUTINE SET_NODAL_VARIABLE_SHOW(VALUE)
integer(kind=glcint), intent(in out) :: value 

SHOW_NODAL_VALUE=VALUE
ISSHOWNODALVALUE=.TRUE.

CALL DRAW_NADAL_VALUE()

RETURN
END SUBROUTINE

SUBROUTINE SET_SLICE_VARIABLE_SHOW(VALUE)
integer(kind=glcint), intent(in out) :: value 

SLICE_PLOT_VARIABLE=VALUE
IF(NSLICE<1) CALL INPUTSLICELOCATION()

CALL SLICEPLOT()
RETURN
END SUBROUTINE


SUBROUTINE SHOW_NodalValue_HANDLER(selection)
integer(kind=glcint), intent(in) :: selection

select case (selection)

case (SHOWNODALVALUE_TOGGLE)
   ISSHOWNODALVALUE = .not. ISSHOWNODALVALUE
end select

CALL DRAW_NADAL_VALUE()
    
ENDSUBROUTINE

SUBROUTINE SET_VECTOR_PLOT_GROUP(VALUE)
integer(kind=glcint), intent(in out) :: value 

VECTOR_PLOT_GROUP=VALUE

IsDrawVector=.true.

CALL VEC_PLOT_DATA()

CALL drawvector()

IF(isPlotStreamLine) THEN
	
	CALL streamline_update()

ENDIF

RETURN
END SUBROUTINE

subroutine Contour_handler(selection)
integer(kind=glcint), intent(in) :: selection
select case (selection)

case (Contour_surfsolid_toggle)
   draw_surface_solid = .not. draw_surface_solid
case (Contour_Line_toggle)
   draw_contour = .not. draw_contour
case(contour_densify)
    Scale_Contour_Num=Scale_Contour_Num*2
	call initialize_contourplot(outvar(CONTOUR_PLOT_VARIABLE).ivo)
    call DrawSurfaceContour()
    call DrawLineContour()
case(contour_sparsify)
    Scale_Contour_Num=Scale_Contour_Num/2
	call initialize_contourplot(outvar(CONTOUR_PLOT_VARIABLE).ivo)
    call DrawSurfaceContour()
    call DrawLineContour()
CASE(Contour_In_DeformedMesh)
    IsContour_In_DeformedMesh=.NOT.IsContour_In_DeformedMesh
    call DrawSurfaceContour()
    call DrawLineContour()
end select

!if(selection/=Contour_Line_toggle) call DrawSurfaceContour()
!if(selection/=Contour_surfsolid_toggle) call DrawLineContour()

endsubroutine

subroutine Vector_handler(selection)
integer(kind=glcint), intent(in) :: selection
select case (selection)


case (Vector_toggle)
   IsDrawVector = .not. IsDrawVector   
case(Vector_lengthen)
   Scale_Vector_len=Scale_Vector_len*2.0
case(Vector_shorten)
   Scale_Vector_len=Scale_Vector_len/2.0
end select

call drawvector()

endsubroutine

subroutine Model_handler(selection)
integer(kind=glcint), intent(in) :: selection
select case (selection)


case (surfgrid_toggle)
   draw_surface_grid = .not. draw_surface_grid
case (edge_toggle)
   show_edge = .not. show_edge 
case (node_toggle)
   show_node = .not. show_node    
case(DeformedMesh)
    draw_surface_grid=.true.
    IsDeformedMesh=.not.IsDeformedMesh
case(Enlarge_Scale_DeformedMesh)
    Scale_Deformed_Grid=Scale_Deformed_Grid*2.0
    if(IsContour_In_DeformedMesh) then
		call  DrawSurfaceContour()
		call  DrawLineContour()  
	endif
case(Minify_Scale_DeformedMesh)
    Scale_Deformed_Grid=Scale_Deformed_Grid/2.0  
    if(IsContour_In_DeformedMesh) then
		call  DrawSurfaceContour()
		call  DrawLineContour()  
	endif
end select

call drawgrid()

endsubroutine

subroutine param_handler(selection)
integer(kind=glcint), intent(in out) :: selection

select case (selection)

case (set_ncontour)
   print *,"Enter number of contour lines:"
   read *, init_num_contour   
   contour_values_given = .false.
   call DrawSurfaceContour()
   call DrawLineContour() 
case (set_contour_val)
   print *,"enter number of contours:"
   read *, num_contour
   if (allocated(actual_contours)) deallocate(actual_contours)
   allocate(actual_contours(num_contour))
   print *,"enter ",num_contour," contour values:"
   read *,actual_contours
   contour_values_given = .true.
   call DrawSurfaceContour()
   call DrawLineContour() 
case (reset_params)

   !num_contour = init_num_contour
   !contour_color = init_contour_color
   !surface_color = init_surface_color
   !minx = init_minx
   !maxx = init_maxx
   !miny = init_miny
   !maxy = init_maxy
   !draw_surface_grid = init_draw_surface_grid
   !draw_surface_solid = init_draw_surface_solid
   !draw_contour = init_draw_contour
   !call fem_draw

end select

end subroutine param_handler

subroutine contour_color_handler(selection)
integer(kind=glcint), intent(in out) :: selection

contour_color = selection
call DrawSurfaceContour()

end subroutine contour_color_handler

subroutine surface_color_handler(selection)
integer(kind=glcint), intent(in out) :: selection

select case(selection)
case(transparency)
    Istransparency=.not.Istransparency
case default
    surface_color = selection
end select
call DrawSurfaceContour()

end subroutine surface_color_handler

subroutine make_menu(submenuid)
integer, intent(in) :: submenuid
integer :: menuid, param_id, contour_color_menu, surface_color_menu
INTEGER::VSHOW_SPG_ID,VSHOW_STRESS_ID,VSHOW_STRAIN_ID,VSHOW_PSTRAIN_ID,&
        VSHOW_SFR_ID,VSHOW_DIS_ID,VSHOW_FORCE_ID,CONTOUR_PLOT_ID,VECTOR_PLOT_ID,&
        VECTOR_PAIR_ID,Model_ID,&
        NODALVALSHOW_SPG_ID,&
        NODALVALSHOW_STRESS_ID,&
        NODALVALSHOW_STRAIN_ID,&
        NODALVALSHOW_PSTRAIN_ID,&
        NODALVALSHOW_SFR_ID,&
        NODALVALSHOW_DIS_ID,&
        NODALVALSHOW_FORCE_ID,&
        Show_NodalValue_ID,&
        SLICE_PLOT_ID,&
        SLICESHOW_SPG_ID,&
        SLICESHOW_STRESS_ID,&
        SLICESHOW_STRAIN_ID,&
        SLICESHOW_PSTRAIN_ID,&
        SLICESHOW_SFR_ID,&
        SLICESHOW_DIS_ID,&
        SLICESHOW_FORCE_ID,&
        STREAMLINE_PLOT_ID

        
contour_color_menu = glutCreateMenu(contour_color_handler)
call glutAddMenuEntry("black",black_contour)
call glutAddMenuEntry("contour value",rainbow_contour)

surface_color_menu = glutCreateMenu(surface_color_handler)
call glutAddMenuEntry("white",white_surface)
call glutAddMenuEntry("rainbow",rainbow_surface)
call glutAddMenuEntry("transparency",transparency)

!param_id = glutCreateMenu(param_handler)
!call glutAddMenuEntry("number of x grid intervals",set_nx)
!call glutAddMenuEntry("number of y grid intervals",set_ny)
!call glutAddMenuEntry("reset to initial parameters",reset_params)

VSHOW_SPG_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(HEAD).VALUE>0) CALL GLUTADDMENUENTRY("HEAD",HEAD)
IF(OUTVAR(PHEAD).VALUE>0) CALL GLUTADDMENUENTRY("PHEAD",PHEAD)
IF(OUTVAR(discharge).VALUE>0) CALL GLUTADDMENUENTRY("Q",discharge) 
IF(OUTVAR(KR_SPG).VALUE>0) CALL GLUTADDMENUENTRY("Kr",KR_SPG)
IF(OUTVAR(MW_SPG).VALUE>0) CALL GLUTADDMENUENTRY("Mw",MW_SPG) 
IF(OUTVAR(GRADX).VALUE>0) CALL GLUTADDMENUENTRY("IX",GRADX) 
IF(OUTVAR(GRADY).VALUE>0) CALL GLUTADDMENUENTRY("IY",GRADY)
IF(OUTVAR(GRADZ).VALUE>0) CALL GLUTADDMENUENTRY("IZ",GRADZ) 
IF(OUTVAR(VX).VALUE>0)CALL GLUTADDMENUENTRY("VX",VX)
IF(OUTVAR(VY).VALUE>0) CALL GLUTADDMENUENTRY("VY",VY) 
IF(OUTVAR(VZ).VALUE>0) CALL GLUTADDMENUENTRY("VZ",VZ)

VSHOW_STRESS_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(SXX).VALUE>0) CALL GLUTADDMENUENTRY("SXX",SXX)
IF(OUTVAR(SYY).VALUE>0) CALL GLUTADDMENUENTRY("SYY",SYY)
IF(OUTVAR(SZZ).VALUE>0) CALL GLUTADDMENUENTRY("SZZ",SZZ) 
IF(OUTVAR(SXY).VALUE>0) CALL GLUTADDMENUENTRY("SXY",SXY)
IF(OUTVAR(SYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("SYZ",SYZ) 
IF(OUTVAR(SZX).VALUE>0)  CALL GLUTADDMENUENTRY ("SZX",SZX) 
IF(OUTVAR(sigma_mises).VALUE>0)  CALL GLUTADDMENUENTRY ("MISES",sigma_mises) 




VSHOW_STRAIN_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(EXX).VALUE>0)  CALL GLUTADDMENUENTRY ("EXX",EXX)
IF(OUTVAR(EYY).VALUE>0)  CALL GLUTADDMENUENTRY ("EYY",EYY)
IF(OUTVAR(EZZ).VALUE>0)  CALL GLUTADDMENUENTRY ("EZZ",EZZ) 
IF(OUTVAR(EXY).VALUE>0)  CALL GLUTADDMENUENTRY ("EXY",EXY)
IF(OUTVAR(EYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("EYZ",EYZ) 
IF(OUTVAR(EZX).VALUE>0)  CALL GLUTADDMENUENTRY ("EZX",EZX) 
IF(OUTVAR(EEQ).VALUE>0)  CALL GLUTADDMENUENTRY ("EEQ",EEQ) 


VSHOW_PSTRAIN_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(PEXX).VALUE>0)  CALL GLUTADDMENUENTRY ("PEXX",PEXX)
IF(OUTVAR(PEYY).VALUE>0)  CALL GLUTADDMENUENTRY ("PEYY",PEYY)
IF(OUTVAR(PEZZ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEZZ",PEZZ) 
IF(OUTVAR(PEXY).VALUE>0)  CALL GLUTADDMENUENTRY ("PEXY",PEXY)
IF(OUTVAR(PEYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEYZ",PEYZ) 
IF(OUTVAR(PEZX).VALUE>0)  CALL GLUTADDMENUENTRY ("PEZX",PEZX)
IF(OUTVAR(PEEQ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEEQ",PEEQ) 

VSHOW_SFR_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(SFR).VALUE>0)  CALL GLUTADDMENUENTRY ("SFR",SFR)
IF(OUTVAR(SFR_SITA).VALUE>0)  CALL GLUTADDMENUENTRY ("SFR_SITA",SFR_SITA)
IF(OUTVAR(SFR_SN).VALUE>0)  CALL GLUTADDMENUENTRY ("Sn(Tension+)",SFR_SN) 
IF(OUTVAR(SFR_TN).VALUE>0)  CALL GLUTADDMENUENTRY ("Tn(CCW+)",SFR_TN)
IF(OUTVAR(SFR_SFRX).VALUE>0)  CALL GLUTADDMENUENTRY ("SFRX",SFR_SFRX) 
IF(OUTVAR(SFR_SFRY).VALUE>0)  CALL GLUTADDMENUENTRY ("SFRY",SFR_SFRY)

VSHOW_DIS_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(DISX).VALUE>0)  CALL GLUTADDMENUENTRY ("X",DISX)
IF(OUTVAR(DISY).VALUE>0)  CALL GLUTADDMENUENTRY ("Y",DISY)
IF(OUTVAR(DISZ).VALUE>0)  CALL GLUTADDMENUENTRY ("Z",DISZ) 
IF(OUTVAR(RX).VALUE>0)  CALL GLUTADDMENUENTRY ("RX",RX)
IF(OUTVAR(RY).VALUE>0)  CALL GLUTADDMENUENTRY ("RY",RY)
IF(OUTVAR(RZ).VALUE>0)  CALL GLUTADDMENUENTRY ("RZ",RZ)
IF(OUTVAR(HEAD).VALUE>0)  CALL GLUTADDMENUENTRY ("HEAD",HEAD)

VSHOW_FORCE_ID=glutCreateMenu(SET_VARIABLE_SHOW)
IF(OUTVAR(NFX).VALUE>0)  CALL GLUTADDMENUENTRY ("FX",NFX)
IF(OUTVAR(NFY).VALUE>0)  CALL GLUTADDMENUENTRY ("FY",NFY)
IF(OUTVAR(NFZ).VALUE>0)  CALL GLUTADDMENUENTRY ("FZ",NFZ) 
IF(OUTVAR(MX).VALUE>0)  CALL GLUTADDMENUENTRY ("MX",MX)
IF(OUTVAR(MY).VALUE>0)  CALL GLUTADDMENUENTRY ("MY",MY)
IF(OUTVAR(MZ).VALUE>0)  CALL GLUTADDMENUENTRY ("MZ",MZ)
IF(OUTVAR(DISCHARGE).VALUE>0)  CALL GLUTADDMENUENTRY ("Q",DISCHARGE)

CONTOUR_PLOT_ID=glutCreateMenu(contour_handler)
call glutAddMenuEntry("toggle contour surface",Contour_surfsolid_toggle)
call glutAddSubMenu("contour surface color",surface_color_menu)
call glutAddMenuEntry("toggle contour line",Contour_Line_toggle)
call glutAddSubMenu("contour line color",contour_color_menu)
call glutAddMenuEntry("Densify contour",contour_densify)
call glutAddMenuEntry("Sparsify contour",contour_Sparsify)
call glutAddMenuEntry("Plot In DeformedGrid",Contour_In_DeformedMesh)
call glutAddMenuEntry("contour values",set_contour_val)
call glutAddSubMenu("DISPLACE",VSHOW_DIS_ID)
call glutAddSubMenu("FORCE",VSHOW_FORCE_ID)
call glutAddSubMenu("SEEPAGE",VSHOW_SPG_ID)
call glutAddSubMenu("STRESS",VSHOW_STRESS_ID)
call glutAddSubMenu("STRAIN",VSHOW_STRAIN_ID)
call glutAddSubMenu("PSTRAIN",VSHOW_PSTRAIN_ID)
call glutAddSubMenu("SFR",VSHOW_SFR_ID)


VECTOR_PAIR_ID=glutCreateMenu(SET_VECTOR_PLOT_GROUP)
IF(OUTVAR(DISX).VALUE>0.AND.OUTVAR(DISY).VALUE>0) THEN
    CALL GLUTADDMENUENTRY ("DISPLACE",VECTOR_GROUP_DIS)   
ENDIF
IF(OUTVAR(VX).VALUE>0.AND.OUTVAR(VY).VALUE>0) THEN
    CALL GLUTADDMENUENTRY ("SEEPAGE_VELOCITY",VECTOR_GROUP_SEEPAGE_VEC)
ENDIF
IF(OUTVAR(GRADX).VALUE>0.AND.OUTVAR(GRADY).VALUE>0) THEN
    CALL GLUTADDMENUENTRY ("SEEPAGE_GRADIENT",VECTOR_GROUP_SEEPAGE_GRAD)
ENDIF
IF(OUTVAR(SFR_SFRX).VALUE>0.AND.OUTVAR(SFR_SFRY).VALUE>0) THEN
    CALL GLUTADDMENUENTRY ("STRESS_FAILUE_FACE",VECTOR_GROUP_SFR)
ENDIF

VECTOR_PLOT_ID=glutCreateMenu(VECTOR_HANDLER)
call glutAddMenuEntry("toggle Vector Plot",Vector_toggle)
call glutAddMenuEntry("Lengthen Vector",Vector_Lengthen)
call glutAddMenuEntry("Shorten Vector",Vector_Shorten)
call glutAddSubMenu("VectorPair",VECTOR_PAIR_ID)

Model_ID=glutCreateMenu(Model_HANDLER)
call glutAddMenuEntry("ShowMesh",surfgrid_toggle)
call glutAddMenuEntry("ShowEdge",edge_toggle)
call glutAddMenuEntry("ShowNode",node_toggle)
call glutAddMenuEntry("DeformedGrid Toggle",DeformedMesh)
call glutAddMenuEntry("++DeformedGridScale",Enlarge_Scale_DeformedMesh)
call glutAddMenuEntry("--DeformedGridScale",Minify_Scale_DeformedMesh)


NodalValShow_SPG_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(HEAD).VALUE>0) CALL GLUTADDMENUENTRY("HEAD",HEAD)
IF(OUTVAR(PHEAD).VALUE>0) CALL GLUTADDMENUENTRY("PHEAD",PHEAD)
IF(OUTVAR(discharge).VALUE>0) CALL GLUTADDMENUENTRY("Q",discharge) 
IF(OUTVAR(KR_SPG).VALUE>0) CALL GLUTADDMENUENTRY("Kr",KR_SPG)
IF(OUTVAR(MW_SPG).VALUE>0) CALL GLUTADDMENUENTRY("Mw",MW_SPG) 
IF(OUTVAR(GRADX).VALUE>0) CALL GLUTADDMENUENTRY("IX",GRADX) 
IF(OUTVAR(GRADY).VALUE>0) CALL GLUTADDMENUENTRY("IY",GRADY)
IF(OUTVAR(GRADZ).VALUE>0) CALL GLUTADDMENUENTRY("IZ",GRADZ) 
IF(OUTVAR(VX).VALUE>0)CALL GLUTADDMENUENTRY("VX",VX)
IF(OUTVAR(VY).VALUE>0) CALL GLUTADDMENUENTRY("VY",VY) 
IF(OUTVAR(VZ).VALUE>0) CALL GLUTADDMENUENTRY("VZ",VZ)

NodalValShow_STRESS_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(SXX).VALUE>0) CALL GLUTADDMENUENTRY("SXX",SXX)
IF(OUTVAR(SYY).VALUE>0) CALL GLUTADDMENUENTRY("SYY",SYY)
IF(OUTVAR(SZZ).VALUE>0) CALL GLUTADDMENUENTRY("SZZ",SZZ) 
IF(OUTVAR(SXY).VALUE>0) CALL GLUTADDMENUENTRY("SXY",SXY)
IF(OUTVAR(SYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("SYZ",SYZ) 
IF(OUTVAR(SZX).VALUE>0)  CALL GLUTADDMENUENTRY ("SZX",SZX) 
IF(OUTVAR(sigma_mises).VALUE>0)  CALL GLUTADDMENUENTRY ("MISES",sigma_mises) 

NodalValShow_STRAIN_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(EXX).VALUE>0)  CALL GLUTADDMENUENTRY ("EXX",EXX)
IF(OUTVAR(EYY).VALUE>0)  CALL GLUTADDMENUENTRY ("EYY",EYY)
IF(OUTVAR(EZZ).VALUE>0)  CALL GLUTADDMENUENTRY ("EZZ",EZZ) 
IF(OUTVAR(EXY).VALUE>0)  CALL GLUTADDMENUENTRY ("EXY",EXY)
IF(OUTVAR(EYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("EYZ",EYZ) 
IF(OUTVAR(EZX).VALUE>0)  CALL GLUTADDMENUENTRY ("EZX",EZX) 
IF(OUTVAR(EEQ).VALUE>0)  CALL GLUTADDMENUENTRY ("EEQ",EEQ) 


NodalValShow_PSTRAIN_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(PEXX).VALUE>0)  CALL GLUTADDMENUENTRY ("PEXX",PEXX)
IF(OUTVAR(PEYY).VALUE>0)  CALL GLUTADDMENUENTRY ("PEYY",PEYY)
IF(OUTVAR(PEZZ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEZZ",PEZZ) 
IF(OUTVAR(PEXY).VALUE>0)  CALL GLUTADDMENUENTRY ("PEXY",PEXY)
IF(OUTVAR(PEYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEYZ",PEYZ) 
IF(OUTVAR(PEZX).VALUE>0)  CALL GLUTADDMENUENTRY ("PEZX",PEZX)
IF(OUTVAR(PEEQ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEEQ",PEEQ) 

NodalValShow_SFR_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(SFR).VALUE>0)  CALL GLUTADDMENUENTRY ("SFR",SFR)
IF(OUTVAR(SFR_SITA).VALUE>0)  CALL GLUTADDMENUENTRY ("SFR_SITA",SFR_SITA)
IF(OUTVAR(SFR_SN).VALUE>0)  CALL GLUTADDMENUENTRY ("Sn(Tension+)",SFR_SN) 
IF(OUTVAR(SFR_TN).VALUE>0)  CALL GLUTADDMENUENTRY ("Tn(CCW+)",SFR_TN)
IF(OUTVAR(SFR_SFRX).VALUE>0)  CALL GLUTADDMENUENTRY ("SFRX",SFR_SFRX) 
IF(OUTVAR(SFR_SFRY).VALUE>0)  CALL GLUTADDMENUENTRY ("SFRY",SFR_SFRY)

NodalValShow_DIS_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(DISX).VALUE>0)  CALL GLUTADDMENUENTRY ("X",DISX)
IF(OUTVAR(DISY).VALUE>0)  CALL GLUTADDMENUENTRY ("Y",DISY)
IF(OUTVAR(DISZ).VALUE>0)  CALL GLUTADDMENUENTRY ("Z",DISZ) 
IF(OUTVAR(RX).VALUE>0)  CALL GLUTADDMENUENTRY ("RX",RX)
IF(OUTVAR(RY).VALUE>0)  CALL GLUTADDMENUENTRY ("RY",RY)
IF(OUTVAR(RZ).VALUE>0)  CALL GLUTADDMENUENTRY ("RZ",RZ)
IF(OUTVAR(HEAD).VALUE>0)  CALL GLUTADDMENUENTRY ("HEAD",HEAD)

NodalValShow_FORCE_ID=glutCreateMenu(SET_NODAL_VARIABLE_SHOW)
IF(OUTVAR(NFX).VALUE>0)  CALL GLUTADDMENUENTRY ("FX",NFX)
IF(OUTVAR(NFY).VALUE>0)  CALL GLUTADDMENUENTRY ("FY",NFY)
IF(OUTVAR(NFZ).VALUE>0)  CALL GLUTADDMENUENTRY ("FZ",NFZ) 
IF(OUTVAR(MX).VALUE>0)  CALL GLUTADDMENUENTRY ("MX",MX)
IF(OUTVAR(MY).VALUE>0)  CALL GLUTADDMENUENTRY ("MY",MY)
IF(OUTVAR(MZ).VALUE>0)  CALL GLUTADDMENUENTRY ("MZ",MZ)
IF(OUTVAR(DISCHARGE).VALUE>0)  CALL GLUTADDMENUENTRY ("Q",DISCHARGE)

Show_NodalValue_ID=glutCreateMenu(SHOW_NodalValue_HANDLER)
call glutAddSubMenu("DISPLACE",NODALVALSHOW_DIS_ID)
call glutAddSubMenu("FORCE",NODALVALSHOW_FORCE_ID)
call glutAddSubMenu("SEEPAGE",NODALVALSHOW_SPG_ID)
call glutAddSubMenu("STRESS",NODALVALSHOW_STRESS_ID)
call glutAddSubMenu("STRAIN",NODALVALSHOW_STRAIN_ID)
call glutAddSubMenu("PSTRAIN",NODALVALSHOW_PSTRAIN_ID)
call glutAddSubMenu("SFR",NODALVALSHOW_SFR_ID)
CALL glutAddMenuEntry("Show Toggle",SHOWNODALVALUE_TOGGLE)

SliceShow_SPG_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(HEAD).VALUE>0) CALL GLUTADDMENUENTRY("HEAD",HEAD)
IF(OUTVAR(PHEAD).VALUE>0) CALL GLUTADDMENUENTRY("PHEAD",PHEAD)
IF(OUTVAR(discharge).VALUE>0) CALL GLUTADDMENUENTRY("Q",discharge) 
IF(OUTVAR(KR_SPG).VALUE>0) CALL GLUTADDMENUENTRY("Kr",KR_SPG)
IF(OUTVAR(MW_SPG).VALUE>0) CALL GLUTADDMENUENTRY("Mw",MW_SPG) 
IF(OUTVAR(GRADX).VALUE>0) CALL GLUTADDMENUENTRY("IX",GRADX) 
IF(OUTVAR(GRADY).VALUE>0) CALL GLUTADDMENUENTRY("IY",GRADY)
IF(OUTVAR(GRADZ).VALUE>0) CALL GLUTADDMENUENTRY("IZ",GRADZ) 
IF(OUTVAR(VX).VALUE>0)CALL GLUTADDMENUENTRY("VX",VX)
IF(OUTVAR(VY).VALUE>0) CALL GLUTADDMENUENTRY("VY",VY) 
IF(OUTVAR(VZ).VALUE>0) CALL GLUTADDMENUENTRY("VZ",VZ)

SliceShow_STRESS_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(SXX).VALUE>0) CALL GLUTADDMENUENTRY("SXX",SXX)
IF(OUTVAR(SYY).VALUE>0) CALL GLUTADDMENUENTRY("SYY",SYY)
IF(OUTVAR(SZZ).VALUE>0) CALL GLUTADDMENUENTRY("SZZ",SZZ) 
IF(OUTVAR(SXY).VALUE>0) CALL GLUTADDMENUENTRY("SXY",SXY)
IF(OUTVAR(SYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("SYZ",SYZ) 
IF(OUTVAR(SZX).VALUE>0)  CALL GLUTADDMENUENTRY ("SZX",SZX) 
IF(OUTVAR(sigma_mises).VALUE>0)  CALL GLUTADDMENUENTRY ("MISES",sigma_mises) 

SliceShow_STRAIN_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(EXX).VALUE>0)  CALL GLUTADDMENUENTRY ("EXX",EXX)
IF(OUTVAR(EYY).VALUE>0)  CALL GLUTADDMENUENTRY ("EYY",EYY)
IF(OUTVAR(EZZ).VALUE>0)  CALL GLUTADDMENUENTRY ("EZZ",EZZ) 
IF(OUTVAR(EXY).VALUE>0)  CALL GLUTADDMENUENTRY ("EXY",EXY)
IF(OUTVAR(EYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("EYZ",EYZ) 
IF(OUTVAR(EZX).VALUE>0)  CALL GLUTADDMENUENTRY ("EZX",EZX) 
IF(OUTVAR(EEQ).VALUE>0)  CALL GLUTADDMENUENTRY ("EEQ",EEQ) 


SliceShow_PSTRAIN_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(PEXX).VALUE>0)  CALL GLUTADDMENUENTRY ("PEXX",PEXX)
IF(OUTVAR(PEYY).VALUE>0)  CALL GLUTADDMENUENTRY ("PEYY",PEYY)
IF(OUTVAR(PEZZ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEZZ",PEZZ) 
IF(OUTVAR(PEXY).VALUE>0)  CALL GLUTADDMENUENTRY ("PEXY",PEXY)
IF(OUTVAR(PEYZ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEYZ",PEYZ) 
IF(OUTVAR(PEZX).VALUE>0)  CALL GLUTADDMENUENTRY ("PEZX",PEZX)
IF(OUTVAR(PEEQ).VALUE>0)  CALL GLUTADDMENUENTRY ("PEEQ",PEEQ) 

SliceShow_SFR_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(SFR).VALUE>0)  CALL GLUTADDMENUENTRY ("SFR",SFR)
IF(OUTVAR(SFR_SITA).VALUE>0)  CALL GLUTADDMENUENTRY ("SFR_SITA",SFR_SITA)
IF(OUTVAR(SFR_SN).VALUE>0)  CALL GLUTADDMENUENTRY ("Sn(Tension+)",SFR_SN) 
IF(OUTVAR(SFR_TN).VALUE>0)  CALL GLUTADDMENUENTRY ("Tn(CCW+)",SFR_TN)
IF(OUTVAR(SFR_SFRX).VALUE>0)  CALL GLUTADDMENUENTRY ("SFRX",SFR_SFRX) 
IF(OUTVAR(SFR_SFRY).VALUE>0)  CALL GLUTADDMENUENTRY ("SFRY",SFR_SFRY)

SliceShow_DIS_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(DISX).VALUE>0)  CALL GLUTADDMENUENTRY ("X",DISX)
IF(OUTVAR(DISY).VALUE>0)  CALL GLUTADDMENUENTRY ("Y",DISY)
IF(OUTVAR(DISZ).VALUE>0)  CALL GLUTADDMENUENTRY ("Z",DISZ) 
IF(OUTVAR(RX).VALUE>0)  CALL GLUTADDMENUENTRY ("RX",RX)
IF(OUTVAR(RY).VALUE>0)  CALL GLUTADDMENUENTRY ("RY",RY)
IF(OUTVAR(RZ).VALUE>0)  CALL GLUTADDMENUENTRY ("RZ",RZ)
IF(OUTVAR(HEAD).VALUE>0)  CALL GLUTADDMENUENTRY ("HEAD",HEAD)

SliceShow_FORCE_ID=glutCreateMenu(SET_SLICE_VARIABLE_SHOW)
IF(OUTVAR(NFX).VALUE>0)  CALL GLUTADDMENUENTRY ("FX",NFX)
IF(OUTVAR(NFY).VALUE>0)  CALL GLUTADDMENUENTRY ("FY",NFY)
IF(OUTVAR(NFZ).VALUE>0)  CALL GLUTADDMENUENTRY ("FZ",NFZ) 
IF(OUTVAR(MX).VALUE>0)  CALL GLUTADDMENUENTRY ("MX",MX)
IF(OUTVAR(MY).VALUE>0)  CALL GLUTADDMENUENTRY ("MY",MY)
IF(OUTVAR(MZ).VALUE>0)  CALL GLUTADDMENUENTRY ("MZ",MZ)
IF(OUTVAR(DISCHARGE).VALUE>0)  CALL GLUTADDMENUENTRY ("Q",DISCHARGE)

SLICE_PLOT_ID=glutCreateMenu(SLICE_handler)
call glutAddMenuEntry("SET LOCTIONS",SLICE_LOCATION_CLICK)
call glutAddMenuEntry("PlotSlice toggle",PLOTSLICE_CLICK)
call glutAddMenuEntry("SliceSurfacePlot toggle",PLOTSLICESURFACE_CLICK)
call glutAddMenuEntry("SliceIsoLinePlot toggle",PLOTSLICEISOLINE_CLICK)
call glutAddSubMenu("DISPLACE",SLICESHOW_DIS_ID)
call glutAddSubMenu("FORCE",SLICESHOW_FORCE_ID)
call glutAddSubMenu("SEEPAGE",SLICESHOW_SPG_ID)
call glutAddSubMenu("STRESS",SLICESHOW_STRESS_ID)
call glutAddSubMenu("STRAIN",SLICESHOW_STRAIN_ID)
call glutAddSubMenu("PSTRAIN",SLICESHOW_PSTRAIN_ID)
call glutAddSubMenu("SFR",SLICESHOW_SFR_ID)

STREAMLINE_PLOT_ID=glutCreateMenu(STREAMLINE_handler)
call glutAddMenuEntry("PICK START POINT",STREAMLINE_LOCATION_CLICK)
call glutAddMenuEntry("PlotStreamLine toggle",Plot_streamline_CLICK)



menuid = glutCreateMenu(menu_handler)
call glutAddSubMenu("Contour",CONTOUR_PLOT_ID)
call glutAddSubMenu("Vector",VECTOR_PLOT_ID)
call glutAddSubMenu("Slice",SLICE_PLOT_ID)
call glutAddSubMenu("Streamline",STREAMLINE_PLOT_ID)
call glutAddSubMenu("NodalValue",Show_NodalValue_ID)
call glutAddSubMenu("Model",Model_ID)
call glutAddSubMenu("View",submenuid)
!call glutAddSubMenu("plotting parameters",param_id)
call glutAddMenuEntry("ShowProbeValue toggle",probe_selected)
call glutAddMenuEntry("quit",quit_selected)


call glutAttachMenu(GLUT_RIGHT_BUTTON)
end subroutine make_menu

end module function_plotter



!---------------------------------------------------------------------------

subroutine plot_func

use opengl_gl
use opengl_glut
!use view_modifier
use function_plotter
use solverds
implicit none

integer :: winid, menuid, submenuid
!real(gldouble)::r1
interface
    subroutine myreshape(w,h)
        integer::w,h
    end subroutine
    subroutine keyboardCB(key,  x,  y)
        integer,intent(in)::key,x,y
    end subroutine
    subroutine arrows(key, x, y)
       integer,intent(in out) :: key, x, y
    endsubroutine
    subroutine motion(x, y)
        integer, intent(in out) :: x, y
    endsubroutine
    subroutine mouse(button, state, x, y)
        integer, intent(in out) :: button, state, x, y
    endsubroutine
endinterface

! Initializations

call SETUP_SUB_TET4_ELEMENT()
call SETUP_EDGE_TBL_TET()
call SETUP_FACE_TBL_TET()

call glutInit
call glutInitDisplayMode(ior(GLUT_DOUBLE,ior(GLUT_RGB,GLUT_DEPTH)))
call glutInitWindowSize(800_glcint,600_glcint)

! Create a window



winid = glutCreateWindow(trim(adjustl(title)))

minx=minval(node.coord(1));maxx=maxval(node.coord(1))
miny=minval(node.coord(2));maxy=maxval(node.coord(2))
minz=minval(node.coord(3));maxz=maxval(node.coord(3))

modelr=((minx-maxx)**2+(miny-maxy)**2+(minz-maxz)**2)**0.5/2.0
model_radius=modelr
init_lookat.x=(minx+maxx)/2.0
init_lookat.y=(miny+maxy)/2.0
init_lookat.z=(minz+maxz)/2.0
if(ndimension<3) then
init_lookfrom.x=init_lookat.x
init_lookfrom.y=init_lookat.y
init_lookfrom.z=3.0*modelr+init_lookat.z
else
init_lookfrom.x=modelr*3.0
init_lookfrom.y=modelr*3.0
init_lookfrom.z=modelr*3.0
endif

IF(OUTVAR(HEAD).VALUE>0) THEN
    CONTOUR_PLOT_VARIABLE=HEAD
ELSEIF(OUTVAR(DISZ).VALUE>0) THEN
    CONTOUR_PLOT_VARIABLE=DISZ
ELSEIF(OUTVAR(DISY).VALUE>0) THEN
    CONTOUR_PLOT_VARIABLE=DISY
ELSEIF(OUTVAR(DISX).VALUE>0) THEN
    CONTOUR_PLOT_VARIABLE=DISX
ELSEIF(OUTVAR(LOCX).VALUE>0) THEN
    CONTOUR_PLOT_VARIABLE=LOCX
ENDIF

!CONTOUR_PLOT_VARIABLE=MAX(HEAD,DISZ,DISY,DISX,LOCX)

SLICE_PLOT_VARIABLE=CONTOUR_PLOT_VARIABLE !INITIALIZATION

call initialize_contourplot(outvar(CONTOUR_PLOT_VARIABLE).ivo)



CALL STEPPLOT.INITIALIZE(1,NNODALQ,RTIME,CALSTEP)

! initialize view_modifier, receiving the id for it's submenu

submenuid = view_modifier_init()

! create the menu

call make_menu(submenuid)

! Set the display callback
call glutreshapefunc(myreshape)
call glutMouseFunc(mouse)
call glutMotionFunc(motion)
call glutSpecialFunc(arrows)
call glutDisplayFunc(display)
!glutTimerFunc(33, timerCB, 33);             // redraw only every given millisec
!//glutIdleFunc(idleCB);                       // redraw whenever system is idle
!glutReshapeFunc(reshapeCB);
call glutKeyboardFunc(keyboardCB);
!glutPassiveMotionFunc(mousePassiveMotionCB);

call initGL(modelr)
! Create the image

CALL STEPPLOT.UPDATE()

!call DrawSurfaceContour()
!call DrawLineContour() 
!call drawvector()
!call drawgrid()

! Let glut take over

call glutMainLoop

end subroutine plot_func

!---------------------------------------------------------------------------




!///////////////////////////////////////////////////////////////////////////////
!// initialize OpenGL
!// disable unused features
!///////////////////////////////////////////////////////////////////////////////
subroutine initGL(r)
use opengl_gl
implicit none
    real(gldouble),intent(in)::r
    real(glfloat)::white(4) = [1,1,1,1];

    call glShadeModel(GL_SMOOTH);                    !// shading mathod: GL_SMOOTH or GL_FLAT
    call glPixelStorei(GL_UNPACK_ALIGNMENT, 4);      !// 4-byte pixel alignment
    !
    !!// enable /disable features
    call glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    !!//glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    !!//glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
    call glEnable(GL_DEPTH_TEST);
    !call glEnable(GL_LIGHTING);
    !
    !call glEnable(GL_TEXTURE_2D);
    call glEnable(GL_CULL_FACE);
    call glEnable(GL_BLEND);
    CALL glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    !// track material ambient and diffuse from surface color, call it before glEnable(GL_COLOR_MATERIAL)
    call glColorMaterial(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE);
    !//glColorMaterial(GL_FRONT_AND_BACK, GL_DIFFUSE);
    call glEnable(GL_COLOR_MATERIAL);
	
    call glClearColor(0.9_glclampf, 0.9_glclampf, 0.9_glclampf, 1.0_glclampf)
    !call glClearColor(0._glclampf, 0._glclampf, 0._glclampf, 0._glclampf);                   !// background color
    call glClearStencil(0);                          !// clear stencil buffer
    call glClearDepth(1._GLclampd);                         !// 0 is near, 1 is far
    call glDepthFunc(GL_LEQUAL);
    

    call initLights(r);

    
    !call glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 128._glfloat);
    !call glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, white);
end subroutine

!///////////////////////////////////////////////////////////////////////////////
!// initialize lights
!///////////////////////////////////////////////////////////////////////////////
subroutine initLights(r)
use opengl_gl
implicit none
    real(gldouble),intent(in)::r
    !// set up light colors (ambient, diffuse, specular)
    real(GLfloat):: lightKa(4) = [0.0_glfloat, 0.0_glfloat, 0.0_glfloat, 1.0_glfloat];  !// ambient light
    real(GLfloat):: lightKd(4) = [1.0_glfloat, 1.0_glfloat, 1.0_glfloat, 1.0_glfloat];  !// diffuse light
    real(GLfloat):: lightKs(4) = [1, 1, 1, 1];           !// specular light
        !// position the light
    real(GLfloat):: lightPos(4);
    
    lightPos(:)= [0., r*3., r*2., 1.] 
    call glLightfv(GL_LIGHT0, GL_AMBIENT, lightKa);
    call glLightfv(GL_LIGHT0, GL_DIFFUSE, lightKd);
    call glLightfv(GL_LIGHT0, GL_SPECULAR, lightKs);


    call glLightfv(GL_LIGHT0, GL_POSITION, lightPos);

    call glEnable(GL_LIGHT0);                        !// MUST enable each light source after configuration
end subroutine


subroutine PickPoint(x,y,Pt1,IEL)

    use opengl_gl
    use opengl_glut
    use solverds
    !use view_modifier
    use function_plotter
    USE MESHGEO
	implicit none    
    integer(kind=glcint),intent(in) ::  x, y
    INTEGER,INTENT(OUT)::IEL
    real(8),intent(out)::pt1(3)
    INTEGER,EXTERNAL::POINTlOC
   	
    

    call GetOGLPos(x, y,Pt1)

    iel=POINTlOC(pt1)


    
    
endsubroutine



subroutine mouse(button, state, x, y)
use function_plotter
implicit none
!          -----
integer(kind=glcint), intent(in out) :: button, state, x, y
!integer,external::POINTlOC,PTINTRIlOC
integer::iel,I
real(8)::Pt1(3)

! This gets called when a mouse button changes
  moving_left = .FALSE.
  moving_MIDDLE= .FALSE.
  if (button == GLUT_LEFT_BUTTON) then
    moving_left = .TRUE.
    select case(state)
    
    case(GLUT_DOWN)
        SELECT CASE(glutGetModifiers())
        CASE(GLUT_ACTIVE_CTRL)
            call ProbeatPoint(x,y)
        CASE(GLUT_ACTIVE_SHIFT)
            call glutSetCursor(GLUT_CURSOR_LEFT_ARROW)
            begin_left = cart2D(x,y)
            left_button_func=PAN
        CASE DEFAULT
            
        
            if(isPickforstreamline) then
                
                call PickPoint(x,y,Pt1,IEL)
                IF(iel==0) then
                    info.str='the picked location is out of zone.Please pick again.'C
                    info.color=red;info.qkey=.true.
                ELSE
                    left_button_func=LB_DRAWLINE
                    LINE_TEMP.V1=PT1
                    LINE_TEMP.V2=PT1
                    LINE_TEMP.SHOW=.TRUE.
                                     
                ENDIF
                
                
            else
                call glutSetCursor(GLUT_CURSOR_LEFT_ARROW)
			    begin_left = cart2D(x,y)
			    left_button_func=ROTATE
            endif
        END SELECT
        
    
    
    case(GLUT_UP)
        if(isPickforstreamline) then
            info.str='Click to Pick more or Press q to exit.'C
            if(info.qkey==.false.) then
                isPickforstreamline=.false.
                LINE_TEMP.SHOW=.FALSE.
                LINE_TEMP.V1=LINE_TEMP.V2
                left_button_func=ROTATE
                info.str=''
                call glutSetCursor(GLUT_CURSOR_LEFT_ARROW)
                return
            endif
			
            IF(NORM2(LINE_TEMP.V1-LINE_TEMP.V2)<1E-3) THEN
                call gen_new_streamline(LINE_TEMP.V1)
            ELSE
                DO I=1,10
                    PT1=LINE_TEMP.V1+(I-1)/9.0*(LINE_TEMP.V2-LINE_TEMP.V1)
                    call gen_new_streamline(PT1)
                ENDDO
            ENDIF
            LINE_TEMP.SHOW=.FALSE.
            LINE_TEMP.V1=LINE_TEMP.V2
            info.color=green;info.qkey=.true. 
        
        ENDIF
        
    
    end select
    
    
  endif
  
  if (button == GLUT_MIDDLE_BUTTON ) then
    if(state == GLUT_DOWN) then
        call glutSetCursor(GLUT_CURSOR_LEFT_ARROW)
        moving_middle = .true.
        begin_middle = cart2D(x,y)
        middle_button_func=ZOOM
    else
        moving_middle = .false.
    endif
    
  endif
  

end subroutine mouse

!          ------
subroutine motion(x, y)
use function_plotter
implicit none
!          ------
integer(kind=glcint), intent(in out) :: x, y
integer::iel
real(8)::Pt1(3)
! This gets called when the mouse moves

integer :: button_function
type(cart2D) :: begin
real(kind=gldouble) :: factor

! Determine and apply the button function

if (moving_left) then
   button_function = left_button_func
   begin = begin_left
else if(moving_middle) then
   button_function = middle_button_func
   begin = begin_middle
end if

select case(button_function)
CASE(LB_DRAWLINE)
    call PickPoint(x,y,Pt1,IEL)
    LINE_TEMP.V2=PT1
case (ZOOM)
   if (y < begin%y) then
      factor = 1.0_gldouble/(1.0_gldouble + .002_gldouble*(begin%y-y))
   else if (y > begin%y) then
      factor = 1.0_gldouble + .002_gldouble*(y-begin%y)
   else
      factor = 1.0_gldouble
   end if
   IF(ISPERSPECT) THEN
        shift%z = shift%z/factor
   ELSE
        xscale_factor = xscale_factor * factor
        yscale_factor = yscale_factor * factor
        zscale_factor = zscale_factor * factor
   ENDIF
   
   
case (PAN)
   shift%x = shift%x + .01*(x - begin%x)
   shift%y = shift%y - .01*(y - begin%y)
case (ROTATE)
   angle%x = angle%x + (x - begin%x)
   angle%y = angle%y + (y - begin%y)

   !call trackball(begin.x, begin.y, real(x,8), real(y,8),axis_rotate,phi_rotate)
   !print *, begin.x, begin.y,x,y
case (SCALEX)
   if (y < begin%y) then
      factor = 1.0_gldouble + .002_gldouble*(begin%y-y)
   else if (y > begin%y) then
      factor = 1.0_gldouble/(1.0_gldouble + .002_gldouble*(y-begin%y))
   else
      factor = 1.0_gldouble
   end if
   xscale_factor = xscale_factor * factor
case (SCALEY)
   if (y < begin%y) then
      factor = 1.0_gldouble + .002_gldouble*(begin%y-y)
   else if (y > begin%y) then
      factor = 1.0_gldouble/(1.0_gldouble + .002_gldouble*(y-begin%y))
   else
      factor = 1.0_gldouble
   end if
   yscale_factor = yscale_factor * factor
case (SCALEZ)
   if (y < begin%y) then
      factor = 1.0_gldouble + .002_gldouble*(begin%y-y)
   else if (y > begin%y) then
      factor = 1.0_gldouble/(1.0_gldouble + .002_gldouble*(y-begin%y))
   else
      factor = 1.0_gldouble
   end if
   zscale_factor = zscale_factor * factor
end select

! update private variables and redisplay

if (moving_left) then
   begin_left = cart2D(x,y)
else if(moving_middle) then
   begin_middle = cart2D(x,y)
endif

if (moving_left .or. moving_middle) then
   call glutPostRedisplay
endif

return
end subroutine motion

!          ------
subroutine arrows(key, x, y)

use function_plotter
implicit none
integer(glcint), intent(in out) :: key, x, y

! This routine handles the arrow key operations

real(kind=gldouble) :: factor

select case(arrow_key_func)

CASE(STEP_KEY)
    select case(key)
    CASE(GLUT_KEY_DOWN,GLUT_KEY_RIGHT)
        STEPPLOT.ISTEP=MOD(STEPPLOT.ISTEP,STEPPLOT.NSTEP)+1        
    CASE(GLUT_KEY_UP,GLUT_KEY_LEFT)
        STEPPLOT.ISTEP=STEPPLOT.ISTEP-1
        IF(STEPPLOT.ISTEP<1) STEPPLOT.ISTEP=STEPPLOT.NSTEP
    ENDSELECT
    
    CALL STEPPLOT.UPDATE()
!case(ZOOM)
!   select case(key)
!   case(GLUT_KEY_DOWN)
!      factor = 1.0_gldouble + .02_gldouble
!   case(GLUT_KEY_UP)
!      factor = 1.0_gldouble/(1.0_gldouble + .02_gldouble)
!   case default
!      factor = 1.0_gldouble
!   end select
!   shift%z = factor*shift%z
!case(PAN)
!   select case(key)
!   case(GLUT_KEY_LEFT)
!      shift%x = shift%x - .02
!   case(GLUT_KEY_RIGHT)
!      shift%x = shift%x + .02
!   case(GLUT_KEY_DOWN)
!      shift%y = shift%y - .02
!   case(GLUT_KEY_UP)
!      shift%y = shift%y + .02
!   end select
!case(ROTATE)
!   select case(key)
!   case(GLUT_KEY_LEFT)
!      angle%x = angle%x - 1.0_gldouble
!   case(GLUT_KEY_RIGHT)
!      angle%x = angle%x + 1.0_gldouble
!   case(GLUT_KEY_DOWN)
!      angle%y = angle%y + 1.0_gldouble
!   case(GLUT_KEY_UP)
!      angle%y = angle%y - 1.0_gldouble
!   end select
!case(SCALEX)
!   select case(key)
!   case(GLUT_KEY_DOWN)
!      factor = 1.0_gldouble/(1.0_gldouble + .02_gldouble)
!   case(GLUT_KEY_UP)
!      factor = 1.0_gldouble + .02_gldouble
!   case default
!      factor = 1.0_gldouble
!   end select
!   xscale_factor = xscale_factor * factor
!case(SCALEY)
!   select case(key)
!   case(GLUT_KEY_DOWN)
!      factor = 1.0_gldouble/(1.0_gldouble + .02_gldouble)
!   case(GLUT_KEY_UP)
!      factor = 1.0_gldouble + .02_gldouble
!   case default
!      factor = 1.0_gldouble
!   end select
!   yscale_factor = yscale_factor * factor
!case(SCALEZ)
!   select case(key)
!   case(GLUT_KEY_DOWN)
!      factor = 1.0_gldouble/(1.0_gldouble + .02_gldouble)
!   case(GLUT_KEY_UP)
!      factor = 1.0_gldouble + .02_gldouble
!   case default
!      factor = 1.0_gldouble
!   end select
!   zscale_factor = zscale_factor * factor
!
end select
   
call glutPostRedisplay

return
end subroutine arrows

subroutine myreshape(w,h)
    use function_plotter    
    implicit none
    integer(glcint)::w,h
    


	real(gldouble):: wL,wH,R,wR,clipAreaXLeft,clipAreaXRight,clipAreaYBottom,clipAreaYTop, &
                    R1,dis1,near,far,xc,yc

    !call reset_view
    
	if (h == 0) h = 1;
	call glViewport(0, 0, w, h);

	R = real(w) / real(h);
    r1=((minx-maxx)**2+(miny-maxy)**2+(minz-maxz)**2)**0.5/2.0
    dis1=((init_lookat.x-init_lookfrom.x)**2+(init_lookat.y-init_lookfrom.y)**2+(init_lookat.z-init_lookfrom.z)**2)**0.5 
    
    near=1.0;far=near+2*r1+dis1*10
    !write(*,'(2G13.6)') 'NEAR=',NEAR,'FAR=',FAR 
    
	call glMatrixMode(GL_PROJECTION);
	call glLoadIdentity();


    !glortho and gluperspective 的参数都是相对于eye坐标的。
    
	if(IsPerspect) then
        call gluPerspective(30.0_gldouble, R, near, far)
    else
        
	    !wL = maxx -minx;	
	    !wH = maxy -miny;
	    !if (wH <= 0) wH = 1.0;
	    !wR = wL / wH;
        !
	    !if (wR > R)	then
		    ! ! Projection clipping area
		    ! clipAreaXLeft = minx;
		    ! clipAreaXRight = maxx;
		    ! clipAreaYBottom = (miny + maxy) / 2 - wL / R / 2.0;
		    ! clipAreaYTop = (miny + maxy) / 2 + wL / R / 2.0;
	    !
	    !else 
		    ! clipAreaXLeft =( minx + maxx) / 2.0 - wH* R / 2.0;
		    ! clipAreaXRight = (minx + maxx) / 2.0 + wH* R / 2.0;
		    ! clipAreaYBottom = miny;
		    ! clipAreaYTop = maxy;
	    !endif
	    !call glOrtho(clipAreaXLeft-init_lookfrom.x, clipAreaXRight-init_lookfrom.x, &
        !             clipAreaYBottom-init_lookfrom.y, clipAreaYTop-init_lookfrom.y,near,far)
        if(R>1) then
            call glOrtho(-r1*R, r1*R, -r1, r1,near,far) 
        else
            call glOrtho(-r1, r1, -r1/R, r1/R,near,far) 
        endif
    endif
    call glMatrixMode(GL_MODELVIEW);
	call glLoadIdentity();


end subroutine

subroutine keyboardCB(key,  x,  y)
    use function_plotter    
    use strings
    implicit none
    integer,intent(in)::key,x,y
    integer::nlen=0,nsubstr=0
    character(len(info.inputstr))::substr(50)
    
    
    INPUTKEY=KEY
   
    
    select case(key)
    case(ichar('q'),ichar('Q'))
        if(INFO.QKEY) then
            info.str=''
            info.inputstr=''           
            INFO.ISNEEDINPUT=.FALSE.
            info.qkey=.false.
        endif
    case DEFAULT
 
    end select
    
    if(info.isneedinput) then
        nlen=len_trim(adjustl(info.inputstr))
        if(nlen>=len(info.inputstr)) info.inputstr=''
        if(key==8) then
            info.inputstr=info.inputstr(1:nlen-1)            
        elseif(key==13) then !enter
            call string_interpreter(info.inputstr,str2realArray)
            if(allocated(info.inputvar)) deallocate(info.inputvar)
            allocate(info.inputvar,source=str2vals)
            info.ninputvar=nstr2vals
            select case(info.func_id)
            case(FUNC_ID_GETSLICELOCATION)
                call getslicelocation()
            end select
            
            info.str=''
            info.inputstr=''
            INFO.NINPUTVAR=0
            if(allocated(info.inputvar)) deallocate(info.inputvar)
            INFO.ISNEEDINPUT=.false.
        else
            info.inputstr=trim(adjustl(info.inputstr))//char(key)
        endif
    ELSE
        INFO.INPUTSTR=''
    endif 
    
    call glutPostRedisplay
    !switch(key)
    !{
    !case 27: // ESCAPE
    !    exit(0);
    !    break;
    !
    !case 'd': // switch rendering modes (fill -> wire -> point)
    !case 'D':
    !    drawMode = ++drawMode % 3;
    !    if(drawMode == 0)        // fill mode
    !    {
    !        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    !        glEnable(GL_DEPTH_TEST);
    !        glEnable(GL_CULL_FACE);
    !    }
    !    else if(drawMode == 1)  // wireframe mode
    !    {
    !        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    !        glDisable(GL_DEPTH_TEST);
    !        glDisable(GL_CULL_FACE);
    !    }
    !    else                    // point mode
    !    {
    !        glPolygonMode(GL_FRONT_AND_BACK, GL_POINT);
    !        glDisable(GL_DEPTH_TEST);
    !        glDisable(GL_CULL_FACE);
    !    }
    !    break;
    !
    !case 'r':
    !case 'R':
    !    // reset rotation
    !    quat.set(1, 0, 0, 0);
    !    break;
    !
    !case ' ':
    !    if(trackball.getMode() == Trackball::ARC)
    !        trackball.setMode(Trackball::PROJECT);
    !    else
    !        trackball.setMode(Trackball::ARC);
    !    break;
    !
    !default:
    !    ;
    !}
endsubroutine
