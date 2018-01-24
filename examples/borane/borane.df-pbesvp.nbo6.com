%oldchk=borane.df-pbesvp.chk
%chk=borane.df-pbesvp.nbo6.chk
%NoSave
#P PBEPBE/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(check) 
guess(read,only) pop(nbo6read)

 Borane DF-BP86/def2-SVP

0   1

$NBO
  archive file=borane.df-pbesvp
$END

! Input file created with: 
!   ../../g09.propnbo6.sh borane.df-pbesvp.com
