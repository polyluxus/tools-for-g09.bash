%oldchk=borane.df-bp86svp.chk
%chk=borane.df-bp86svp.freq.T393-15P1-5.chk
#P BP86/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) 
guess(read) freq Temperature=393.15 Pressure=1.5

 Borane DF-BP86/def2-SVP

0   1

! Input file created with: 
!   ../../g09.freqinput.sh -T393.15 -P1.5 borane.df-bp86svp.com
