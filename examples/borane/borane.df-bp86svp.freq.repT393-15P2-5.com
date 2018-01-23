%oldchk=borane.df-bp86svp.freq.T393-15P1-5.chk
%chk=borane.df-bp86svp.freq.T393-15P1-5.repT393-15P2-5.chk
%NoSave
#P BP86/def2SVP/W06 DenFit scf(xqc,MaxConventionalCycle=500) int(ultrafinegrid) 
gfinput gfoldprint iop(6/7=3) symmetry(loose)      geom(check) guess(read) 
freq(ReadFC) Temperature=393.15 Pressure=2.5

 Borane DF-BP86/def2-SVP

0   1

! Input file created with: 
!   ../../g09.freqinput.sh -R -P2.5 -T393.15 borane.df-bp86svp.freq.T393-15P1-5.com
