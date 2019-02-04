#!/bin/csh

# Put "_nws19" or "_nws20" in front of filename or directory name. and follow with a period. 
# built to match ensemble_avg_plot.ncl better. 
#
# "nws19" can be the modelstr.  It kind of is like a model string (or name). It is a NWS=19 parametric Holland model. 
foreach storm (HARVEY IKE IRMA CHARIKE CHARLEY MATTHEW)
    foreach nws (19 20)
        foreach perturb (veer control rmax vmax speed track track_scaled)
            rename -v ${perturb}_nws${nws} nws${nws}.${perturb} $storm/${perturb}_nws${nws}*
            rename -v ${perturb}_nws${nws} nws${nws}.${perturb} $storm/nws${nws}.${perturb}*/${perturb}_nws${nws}*
        end
    end
end
