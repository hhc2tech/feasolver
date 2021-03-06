      SUBROUTINE SEARCH(ILS,PRODR,ETA,AMP,ETMXA,ETMNA,IWRIT,IWR,ICO,
     1           NLSMXP)
C
C     FROM 9.2.2.1
C     PERFORMS LINE LOCAL LINE-SEARCH TO GET STEP-LENGTH
C     IN ETA(ILS+2)
C     ETA 1-ILS HAS PREVIOUS STEP-LENGTHS (ETA(1)=0.,ETA(2)=1.)
C     WITH EQUIVALENT INNER-PRODUCT RATIOS IN PRODR, (PRODR(1)=1.)
C     AMP HAS MAX AMP. FACTOR FOR STEP-LENGTH,
C     ETMXA AND ETMNA HAVE MAX AND MIN ALLOWED STEP-LENGTHS
C     ICO ENTERS =1 IF MAX OR MIN STEP-LENGTH USED ON PREVIOUS SEARCH
C     EXITS SET TO 1 IF USED ON PRESENT SEARCH
C           OR 2 IF ALSO USED ON LAST SEARCH
C
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      DIMENSION PRODR(NLSMXP),ETA(NLSMXP)
C
C     OBTAIN INEG=NO OF PREVIOUS S-L WITH NEG. RATIO NEAREST TO ORIGIN
C     AS WELL AS MAX PREVIOUS STEP-LENGTH, ETMAXP
C     IF NO NEGATIVE PRODUCTS, INEG ENDS AS 999
C
      INEG=999
      ETANEG=1.D5
      ETMAXP=0.D0
      DO 10 I=1,ILS+1
      IF (ETA(I).GT.ETMAXP) ETMAXP=ETA(I)
      IF (PRODR(I).GE.0.D0) GO TO 10
      IF (ETA(I).GT.ETANEG) GO TO 10
      ETANEG=ETA(I)
      INEG=I
   10 CONTINUE
C
C     BELOW NOW ALLOWS INTERPOLATION
      IF (INEG.NE.999) THEN
C     FIND IPOS=NO OF PREVIOUS S-L WITH POS RATIO THAT IS
C     CLOSEST TO INEG (BUT WITH SMALLER S-L)
      IPOS=1
      DO 20 I=1,ILS+1
      IF (PRODR(I).LT.0.D0) GO TO 20
      IF (ETA(I).GT.ETA(INEG)) GO TO 20
      IF (ETA(I).LT.ETA(IPOS)) GO TO 20
      IPOS=I
   20 CONTINUE
C
C     INTERPOLATE TO GET S-L ETAINT
      ETAINT=PRODR(INEG)*ETA(IPOS)-PRODR(IPOS)*ETA(INEG)
      ETAINT=ETAINT/(PRODR(INEG)-PRODR(IPOS))
C     ALTERNATIVELY GET ETAALT ENSURING A REASONABLE CHANGE
      ETAALT=ETA(IPOS)+0.2*(ETA(INEG)-ETA(IPOS))
C     TAKE MAX
      IF (ETAINT.LT.ETAALT) ETAINT=ETAALT
C     OR MIN STEP-LENGTH
      IF (ETAINT.LT.ETMNA) THEN
      ETAINT=ETMNA
      IF (ICO.EQ.1) THEN
      ICO=2
      WRITE (IWR,1010)
 1010 FORMAT(/,1X,'MIN STEP-LENGTH REACHED TWICE')
      ELSEIF (ICO.EQ.0) THEN
      ICO=1
      ENDIF
      ENDIF
C
      ETA(ILS+2)=ETAINT
      IF (IWRIT.EQ.1) THEN
      WRITE (IWR,1001) (ETA(I),I=1,ILS+2)
 1001 FORMAT(/,1X,'L-S PARAMETERS',/,1X,'ETAS  ',(6G11.3))
      WRITE(IWR,1002) (PRODR(I),I=1,ILS+1)
 1002 FORMAT(/,1X,'RATIOS',(6G11.3))
      ENDIF
      RETURN
C
C
C     BELOW WITH EXTRAPOLATION
      ELSE IF (INEG.EQ.999) THEN
C     SET MAX TEMP STEP LENGTH
      ETMXT=AMP*ETMAXP
      IF (ETMXT.GT.ETMXA) ETMXT=ETMXA
C     EXTRAP. BETWEEN CURRENT AND PREVIOUS
      ETAEXT=PRODR(ILS+1)*ETA(ILS)-PRODR(ILS)*ETA(ILS+1)
      ETAEXT=ETAEXT/(PRODR(ILS+1)-PRODR(ILS))
      ETA(ILS+2)=ETAEXT
C     ACCEPT IF ETAEXT WITHIN LIMITS
      IF (ETAEXT.LE.0.D0.OR.ETAEXT.GT.ETMXT) ETA(ILS+2)=ETMXT
      IF (ETA(ILS+2).EQ.ETMXA.AND.ICO.EQ.1) THEN
      WRITE (IWR,1003)
 1003 FORMAT(/,1X,' MAX STEP-LENGTH AGAIN')
C     STOP 'SEARCH 1003'
      ICO=2
      RETURN
      ENDIF
      IF (ETA(ILS+2).EQ.ETMXA) ICO=1
      IF (IWRIT.EQ.1) THEN
      WRITE (IWR,1001) (ETA(I),I=1,ILS+2)
      WRITE (IWR,1002) (PRODR(I),I=1,ILS+1)
      ENDIF
      ENDIF
      RETURN
      END
