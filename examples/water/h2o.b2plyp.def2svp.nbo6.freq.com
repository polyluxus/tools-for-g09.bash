%oldchk=h2o.b2plyp.def2svp.nbo6.chk
%chk=h2o.b2plyp.def2svp.nbo6.freq.chk
#p b2plyp/def2SVP
freq geom=check guess=read
gfinput gfoldprint iop(6/7=3)
scrf(pcm,solvent=toluene)
pop=full pop=nbo6 pop=allorbitals
symmetry=loose

Water B2PLYP/def2-SVP

0 1

