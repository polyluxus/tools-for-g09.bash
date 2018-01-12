%chk=methane.df-bp86svp.chk
#P BP86/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose)  geom=check 
guess(read,only) pop=nbo6read

 Methane DF-BP86/def2-SVP

0   1

$NBO
  archive file=methane.df-bp86svp
$END

