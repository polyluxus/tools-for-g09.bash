%oldchk=ammonia.df-b97d3svp.chk
%chk=ammonia.df-b97d3svp.nbo6.chk
%NoSave
#P B97D3/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) 
guess(read,only) pop(nbo6read)

 Ammonia DF-B97D3/def2-SVP

0   1

$NBO
  archive file=ammonia.df-b97d3svp.nbo6
$END

! Input file created with: 
!   ../../g09.propnbo6.sh ammonia.df-b97d3svp.gjf
