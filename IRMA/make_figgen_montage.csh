#!/bin/csh

foreach f (`seq 1 72`)
    printf "montage -label '%%d/%%f' -geometry 70%% "
    set title=`ndate.exe $f 2017091000`
    set i=0
    foreach d (2017091000 2017090900 2017090800 2017090700 2017090600 2017090500)
        set ff=`expr $f + 24 \* $i`
        set ff=`printf '%04d' $ff`
        @ i++
        printf "uni.$d.ecic/figuregen/IRMA.uni.ecic$ff.png "
    end
    echo "-title $title $title.png"
end
