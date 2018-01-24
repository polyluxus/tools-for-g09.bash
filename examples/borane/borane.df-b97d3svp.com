%chk=borane.df-b97d3svp.chk
#P B97d3/def2SVP/W06
DenFit 
opt(MaxCycle=100  MaxStep=10 VeryTight NoEigenTest) 
scf(xqc MaxConventionalCycle = 500) 
int(ultrafinegrid)
gfinput gfoldprint iop(6/7=3)
symmetry(loose)

Borane DF-BP86/def2-SVP

0 1
B        0.000000000      0.000000000     -0.070572069
H       -0.937179603      0.000000000      0.326850931
H        0.468589801      0.811621344      0.326850931
H        0.468589801     -0.811621344      0.326850931


