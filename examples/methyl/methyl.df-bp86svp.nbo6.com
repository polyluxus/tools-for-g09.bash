%chk=methyl.df-bp86svp.chk
#P UBP86/def2SVP/W06 DenFit scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) 
guess(read,only) pop(nbo6read) output(wfn) pop(AllOrbitals) volume

 Methane DF-BP86/def2-SVP

0   2

$NBO
  archive file=methyl.df-bp86svp
   PLOT BNDIDX
$END

methyl.df-bp86svp.wfn

!!!!! To create this file the following command was used:
! g09.propnbo6.sh -r "output=wfn, pop=AllOrbitals" -n "PLOT BNDIDX" -r volume -t methyl.df-bp86svp.wfn methyl.df-bp86svp.com 
!
