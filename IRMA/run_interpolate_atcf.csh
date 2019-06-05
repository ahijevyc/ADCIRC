foreach f ( `seq 1 50` )
    set f2=`printf '%02d' $f`
    grep " EE$f2, " /glade/work/ahijevyc/atcf/archive/2017/aal112017.ecmwf.ens.dat | grep " 2017090812, 03," > t.dat
    python ~/bin/interpolate_atcf.py t.dat
    mv /glade/scratch/ahijevyc/temp/t.atcf ECMWF.0p125.2017090812.PF$f/fort.22
    if ($status != 0) break
end
