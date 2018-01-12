#p MP2/def2SVP
opt scf(xqc)
gfinput gfoldprint iop(6/7=3)
scrf(pcm,solvent=toluene)
pop=full pop=nbo6 pop=allorbitals

Water MP2/def2-SVP

0 1
O
H 1 1.2
H 1 1.2 2 109.0

