%oldchk=ammonia.pbesvp.chk
%NoSave
#P PBEPBE/def2SVP/W06 DenFit  scf(xqc,MaxConventionalCycle=500) 
int(ultrafinegrid) gfinput gfoldprint iop(6/7=3) symmetry(loose) geom(allcheck) 
guess(read,only) output=wfn

ammonia.pbesvp.wfn

