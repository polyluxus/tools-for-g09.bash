%oldchk=ammonia.df-b97d3svp.chk
%chk=ammonia.df-b97d3svp.freq.chk
#P B97D3/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) 
guess(read) freq

 Ammonia DF-B97D3/def2-SVP

0   1

! Input file created with: 
!   ../../g09.freqinput.sh ammonia.df-b97d3svp.gjf
