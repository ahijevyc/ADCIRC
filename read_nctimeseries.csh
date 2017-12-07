#!/usr/bin/perl -w
use strict;

# Usage
# ncdump -v inundation_volume <file.timeseries.nc> | read_timeseries.csh
my $data_start = 0;
while ($_ = <>) {
	$data_start = 1 if /^data:/;
	next unless $data_start == 1;
	chomp;
	s/(.+=)//;
	s/_/0/g;
	s/,/\n/g;
	s/[;} ]+//g;
	next unless /\d/;
	print;
}
print "\n"; 
