# Put model name first
# Treat nws19 and nws20 as models.

foreach modelstr (rmax+100 rmax+25 rmax+50 speed+10 speed-5 veer+1 veer+3 veer+5 veer+7 vmax-3 vmax-7 rmax-33 rmax+75 speed-15 speed+5 veer-2 veer-4 veer-6 vmax+3 vmax+7 rmax-43 speed+15 veer+2 veer+4 veer+6 vmax-1 vmax-5 rmax-20 rmax-50 speed-10 speed+20 veer-1 veer-3 veer-5 veer-7 vmax+1 vmax+5)
    cd $modelstr
    foreach region (FloridaSW FloridaNE)
        #foreach f (${modelstr}$region.minus_astronomical_tideFalse_1.00m.MHHW.000???.png)
        #set i=`echo $f | sed -e 's/.*\.\(00[0-9][0-9][0-9][0-9]\)\.png/\1/'`
            #mv $f $modelstr.minus_astronomical_tideFalse_1.00m.MHHW.stride02.-88.0E-77.0E24.0N35.0N${region}.$i.png
            #if ($status != 0) break
            #end
        mv ${modelstr}$region.minus_astronomical_tideFalse_1.00m.MHHW.stride02.-88.0E-77.0E24.0N35.0N$region.timeseries.nc ${modelstr}.minus_astronomical_tideFalse_1.00m.MHHW.stride02.-88.0E-77.0E24.0N35.0N$region.timeseries.nc 
        if ($status != 0) break
    end
    cd ..
end

