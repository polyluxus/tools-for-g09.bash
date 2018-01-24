%oldchk=borane.df-pbesvp.chk
%chk=borane.df-pbesvp.prop.chk
%NoSave
#P PBEPBE/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(allcheck) 
guess(read,only) output=wfx

borane.df-pbesvp.wfx

! Input file created with: 
!   ../../g09.propwfx.sh borane.df-pbesvp.com
