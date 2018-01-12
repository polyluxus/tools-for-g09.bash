%chk=h2o.df-bp86.def2svp.chk
#P BP86/def2SVP/W06 DenFit scf(xqc,MaxConventionalCycle=500) int(ultrafinegrid) 
gfinput gfoldprint iop(6/7=3) symmetry(loose) geom=allcheck guess(read,only) 
output=wfx

h2o.df-bp86.def2svp.wfx

