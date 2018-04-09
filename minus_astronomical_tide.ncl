undef("subtract_tide")
function subtract_tide (zeta, model_file)

; I use this in bulge_timeseries.ncl.
; I would like to also use it in perfect_cntl.ncl, but 
; zeta_max is not a time series. 
; 

local coldstart_file, modeldir, ntime, solid_ground_height, zeta_nostorm
begin

    ; Subtract water level with no storm. Just astronomical tide.
    ; This will give storm surge (the change in water level due to storm).
    ;
    ; Change missing values (over dry land) to -depth (solid ground height).
    ; Change for 1) with-tide water height (zeta) and
    ;            2) without-tide water height zeta (assigned to cse).
    ;
    ; Deal with different-length time series.

    ; Input
    ; zeta - storm tide (storm+astronomical tide) water level over time
    ; model_file  - used to locate coldstart_extend and allow longer coldstart_extend
    ;               time series for Irma, and shorter time series for speed perturbations.

    ; Output
    ; zeta - storm surge over time (storm-only, no astronomical tide)


    modeldir = systemfunc("dirname "+model_file) + "/"
    coldstart_file = modeldir + "../coldstart_extend/" + systemfunc("basename "+model_file) + ".nc"
    cse = addfile(coldstart_file, "r")
    if(.not.isfilepresent(coldstart_file)) then
        print("Did not find "+coldstart_file)
        print("Trim coldstart domain with modelstr='coldstart_extend' first.")
        exit
    end if 
    solid_ground_height = reshape(-cse->depth,dimsizes(cse->zeta))

    ; Change missing values in astronomical tide-only run to solid ground height (-depth).
    ; Now zeta is surface height of water or land (whichever is higher).
    zeta_nostorm = where(ismissing(cse->zeta), solid_ground_height, cse->zeta)

    ; Deal with different length time series.
    ntime = dimsizes(zeta&time)
    if(ntime.lt.dimsizes(cse->zeta&time))then
        print("Perturbed time series shorter than coldstart_extend.")
        ; Can't check for "speed+" because of nws_19 stuff
        if(ismissing(str_index_of_substr(model_file,"speed",1)).or.\
           ismissing(str_index_of_substr(model_file,"IRMA", 1)) ) then 
            print("expected with positive speed and Irma")
            print("not "+modelstr+" and "+stormname)
            exit
        end if
        print("Truncating coldstart_extend.")
        solid_ground_height := solid_ground_height(0:ntime-1,:)
        zeta_nostorm        :=        zeta_nostorm(0:ntime-1,:)
    end if

    ; Change missing values in storm run to solid ground height (-depth).
    zeta = where(ismissing(zeta),solid_ground_height,zeta)


    print("subtracting astronomical tide from storm tide")
    zeta = zeta - zeta_nostorm
    zeta@minus_astronomical_tide = minus_astronomical_tide
    zeta@long_name = "storm surge (storm tide minus astronomical tide)"
    print("subtracted astronomical tide")

    return zeta
end

