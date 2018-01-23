%oldchk=ammonia.pbesvp.chk
%chk=ammonia.pbesvp.freq.chk
#P PBEPBE/def2SVP/W06 DenFit scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) 
guess(read) freq(noraman temp=100 pre=5)

 Ammonia DF-PBE/def2-SVP

0   1

