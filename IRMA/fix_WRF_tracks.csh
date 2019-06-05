#!/bin/csh

# Add hours 0-2 to the beginning of atcf file.
# copy hour 3
head -n 1 $1 | sed -e 's/,   3, /,   0, /'> t
head -n 1 $1 | sed -e 's/,   3, /,   1, /'>> t
head -n 1 $1 | sed -e 's/,   3, /,   2, /'>> t
cat $1 >> t

if ($status == 0) mv t $1

