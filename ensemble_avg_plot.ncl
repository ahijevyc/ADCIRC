load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/p/work/ahijevyc/ADCIRC/get_MHHW.ncl" ; get hgt_MHHW, areaCell, sfc_sub_state

; forked from simple_plot.ncl Nov 13 2015
; Updated and adapted for hwt2017 ensemble Feb 2018


begin
    ; Run first with type="avg"
    if(.not.isvar("type"))then
        type = "max"
    end if
    if(.not.isvar("modelstr"))then
        modelstr = "uni"
    end if
    if(.not.isvar("stormname"))then
        stormname = "IRMA"
    end if
    stride = 1
    basedir = "/glade/scratch/ahijevyc/"+modelstr+"/2017090700/" 
    basedir = "/glade/scratch/mpasrt/"+modelstr+"/201709*/ecic/" 
    outdir  = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
    ; zoom level
    if(.not.isdefined("zoom")) then
        zoom = 1
    end if
    ; region - not needed. Just use zoom=2 for FloridaSW
    if(.not.isvar("minus_astronomical_tide"))then
        minus_astronomical_tide = False
    end if
    if(.not.isvar("thresh"))then
        thresh = 0.0 ; inundation threshold
    end if
    thresh_string = sprintf("%4.2fm", thresh)
    if(.not.isvar("dryland"))then
        ; Baseline for normally-dry land LMSL>=0 or MHHW>=0
        dryland= "MHHW" ; or "LMSL" 
    end if
    ; Sanity check for misspelled dryland
    if(.not.any(dryland.eq.(/"MHHW","LMSL"/)))then
        print("Unexpected dryland: "+dryland)
        print("Expected MHHW or LMSL")
        exit
    end if
    if(type.eq."total".and.thresh.eq.0.)then
        print("type=total and thresh=0")
        print("Set positive threshold.")
        exit
    end if

    res = True
    ; Assign domain min/max lat/lon attributes to res.
    res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))


    ; hwt2017 ensemble
    ;members    = systemfunc("ls "+basedir+"ens_*/latlon_0.125deg_000km/maxele.63.nc")
    ;trackfiles = systemfunc("ls "+basedir+"ens_*/latlon_0.500deg_025km/gfdl_tracker/tracker/IrmaTrack.atcf"  )

    ; uni time-lagged ensemble
    ;members    = systemfunc("ls "+basedir+"latlon_0.125deg_000km/maxele.63.nc")
    ;trackfiles = systemfunc("ls "+basedir+"latlon_0.500deg_025km/gfdl_tracker/tracker/fort.64.IRMA")
    
    ; perturbed ensemble (where modelstr="veer", or whatever)
    ; ncl 'modelstr="vmax_nws19"' 'type="total"' thresh=1 ../ensemble_avg_plot.ncl
    members    := systemfunc("ls /glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"*/maxele.63.nc")
    trackfiles := systemfunc("ls /glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"*/fort.22")


    ensemble =  addfiles(members, "r")
    ListSetType(ensemble, "join")
    f = ensemble[0]

    domainString = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + \
                   sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF)
    outfile = outdir+modelstr+".minus_astronomical_tide"+minus_astronomical_tide+"_"+thresh_string+"."+dryland + \
              "."+sprintf("stride%02.0f.",stride)+domainString+"."+type

    zeta_max   = ensemble[:]->zeta_max
    depth      = ensemble[:]->depth

    inundation = zeta_max + depth
    ; Set missing values to zero. Don't use num() to count non-missing values (zero is not missing but is not True either).
    inundation = where(ismissing(inundation),0.,inundation)

    res@cnLevelSelectionMode     = "ManualLevels"
    res@cnMinLevelValF           =  1e-9 
    res@cnMaxLevelValF           =  2.
    res@cnLevelSpacingF          =  0.2
    if(type.eq."mean")then
        print("Use avg, not mean.")
        exit
    end if
    if(type.eq."count")then
        print("Use total, not count.")
        exit
    end if
    if(type.eq."avg")then
        x_inundation = dim_avg_n_Wrap(inundation, 0)
    end if
    if(type.eq."max")then
        x_inundation = dim_max_n_Wrap(inundation, 0)
    end if
    if(type.eq."prob")then
        break_thresh = where(inundation.ge.thresh,1,0)
        wgt = new(dimsizes(members), "float")
        wgt = 1.
        x_inundation = 100 * dim_avg_wgt_n_Wrap(break_thresh, wgt, 0, 0) 
        x_inundation@units     = "%"
        res@cnMinLevelValF     =   5.
        res@cnMaxLevelValF     =  95.
        res@cnLevelSpacingF    =  10.
    end if
    if(type.eq."total")then
        break_thresh = where(inundation.ge.thresh,1,0)
        wgt = new(dimsizes(members), "float")
        wgt = 1.
        x_inundation = dim_sum_wgt_n_Wrap(break_thresh, wgt, 0, 0)
        x_inundation@units     = "count"
        res@cnMinLevelValF     =  0.
        res@cnMaxLevelValF     =  dimsizes(members)
        res@cnLevelSpacingF    =  1.
        res@lbLabelPosition    = "Center"
        res@lbLabelAlignment   = "BoxCenters"
    end if
    if(type.eq."min")then
        x_inundation = dim_min_n_Wrap(inundation, 0)
    end if
    printMinMax(x_inundation,False)

    ; Only retain land values and low-lying land nodes below MSL (sfc_sub_state=1, or "startDry" nodes). 
    x_inundation = mask(x_inundation, f->depth.le.0 .or. (sfc_sub_state.eq.1), True)
    x_inundation@long_name = modelstr+"~C~ensemble " + type + " maximum inundation >="+thresh_string
    if(.not.isatt(x_inundation,"units"))then
        x_inundation@units     = zeta_max@units
    end if

    if(dryland.eq."MHHW")then
        print(num(.not.ismissing(x_inundation))+" inundated nodes before masking nodes below MHHW=0")
        ; Preserve nodes with missing MHHW (where Vdatum couldn't convert, like over land or deep into Gulf)
        ; or MHHW >= 0 (above normally dry land).
        x_inundation         = mask(x_inundation, ismissing(hgt_MHHW).or.hgt_MHHW.ge.0, True)
        print(num(.not.ismissing(x_inundation))+" inundated nodes after masking nodes below MHHW=0")
    end if


    wtype    = "png"
    wtype@wkWidth  = 2048 
    wtype@wkHeight = 2048 
    wks = gsn_open_wks(wtype,outfile)
    gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")

        
    res@sfXArray                 = f->x
    res@sfYArray                 = f->y
    res@sfDataArray              = x_inundation


    res@cnFillOn                 = True
    res@cnLinesOn                = False
    res@cnFillMode               = "RasterFill"
    res@lbTitleString            = x_inundation@long_name
    res@lbTitleFontHeightF       = 0.018
    res@lbTitlePosition          = "Bottom"

    ; Don't advance the frame.
    res@gsnFrame = False

    res@mpDataBaseVersion       = "HighRes"     ; "MediumRes" will run faster.
    res@mpLimitMode             = "LatLon"
    res@mpPerimOn               = False
    res@pmTickMarkDisplayMode   = "Always"    ; Turn on map tickmarks.
    lres                        = True
    lres@gsLineThicknessF       =  2.
    lres@gsLineLabelFontHeightF = 0.009

    map := gsn_csm_contour_map(wks,x_inundation,res)

    ; draw tracks for all members
    do iveer=0,dimsizes(trackfiles)-1  
        trackfile = trackfiles(iveer)
        iens = str_index_of_substr(trackfile,"/ens_",1)
        modelstr = str_get_cols(trackfile,iens+1,iens+6)
        modelstr = str_sub_str(modelstr,"/","") ; Remove slashes
        if(fileexists(trackfile))then
            print("reading "+trackfile)
            adeck := read_atcf(trackfile)
            tracklon := adeck@lon
            tracklat := adeck@lat
            lres@gsLineLabelString = modelstr
            gsn_polyline(wks,map,tracklon,tracklat,lres)
        end if
    end do
    
    txres = True
    txres@txFontHeightF = 0.01
    txres@txJust        = "BottomLeft"
    gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)

    frame(wks)
    print("made "+outfile+"."+wtype)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; Get standard deviation of inundation across ensemble.
    if(False)then
        infile = outdir+"ens_"+type+".maxele.63.nc"
        if (fileexists(infile)) then
            print("using old "+infile)
        else
            members = basedir+"ens_*/latlon_0.125deg_000km/maxele.63.nc"
            ; make average file.
            avg_file    = outdir   +"ens_avg.maxele.63.nc"
            stddev_file = outdir+"ens_stddev.maxele.63.nc"
            system("ncea -O -y avg "+members+" "+avg_file)
            if(type.eq."stddev")then
                system("cp "+avg_file+" "+infile)
                system("ncecat -O -v zeta_max "+members+" out.nc")
                system("ncbo -O -y subtract -v zeta_max out.nc "+avg_file+" out.nc")
                system("ncwa -O -a record -y rmssdn out.nc out.nc")
                system("ncks -A out.nc "+infile)
            end if
            if(type.eq."zscore")then
                print("Creating zscore file. See NCL script for commands.")
                system("cp  "+avg_file+" "+infile) ; copy all variables to zscore file, work on zeta_max later
                system("ncecat -O "+avg_file+" out.nc");  Wrap out.nc in degenerate "record" dimension
                system("ncwa -O -a record -B 'zeta_max >= 0.01' out.nc out.nc")
                system("ncbo -O -y divide -v zeta_max "+stddev_file+" "+avg_file+" out.nc")
                system("ncks -A out.nc "+infile)
            end if
        end if
    end if
end

