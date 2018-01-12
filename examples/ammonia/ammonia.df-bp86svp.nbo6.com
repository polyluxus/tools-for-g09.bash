%chk=ammonia.df-bp86svp.chk
%NoSave
#P BP86/def2SVP/W06 DenFit scf(xqc,MaxConventionalCycle=500) int(ultrafinegrid) 
gfinput gfoldprint iop(6/7=3) symmetry(loose) geom=check guess(read,only) 
pop=nbo6read

 Ammonia DF-BP86/def2-SVP

0   1

$NBO
  archive file=ammonia.df-bp86svp
$END

