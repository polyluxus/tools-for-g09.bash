#P PBEPBE/def2SVP/W06
DenFit 
opt (MaxCycle=100) scf=(xqc, 
MaxConventionalCycle=500) 
int = (ultrafinegrid)
gfinput gfoldprint iop(6/7=3)
symmetry=loose

Methane DF-PBE/def2-SVP

0 1
C        0.000000000      0.000000000      0.000000000
H        0.630397000      0.630397000      0.630397000
H        0.630397000     -0.630396997     -0.630397003
H       -0.630397003      0.630397000     -0.630396997
H       -0.630396997     -0.630397003      0.630397000

