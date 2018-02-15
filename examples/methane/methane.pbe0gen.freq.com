%oldchk=methane.pbe0gen.chk
%chk=methane.pbe0gen.freq.chk
#P PBE1PBE/ChkBasis  scf(xqc,MaxConventionalCycle=500) int(ultrafinegrid) 
gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) guess(read) freq

 Methane PBE0/C:6-31G*;H:3-21G

0   1

! Input file created with: 
!   ../../g09.freqinput.sh methane.pbe0gen.gjf
