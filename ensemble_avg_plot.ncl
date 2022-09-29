load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/work/ahijevyc/ADCIRC/get_MHHW.ncl";get hgt_MHHW, areaCell, sfc_sub_state, get_ADCIRC_control_str

; forked from simple_plot.ncl Nov 13 2015
; Updated and adapted for hwt2017 ensemble Feb 2018
; 
; PURPOSE
; read maxele.63.nc for several files and plot probability of inundation above a threshold.

; USAGE
; ncl 'type="prob"' 'modelstr="WRF.2017090512"' thresh=1 zoom=2 ensemble_avg_plot.ncl
; assumes maxele.63.nc files are in subdirectories named
; WRF.2017090512.EPS_01.27km3km
; WRF.2017090512.EPS_02.27km3km
; ...
; WRF.2017090512.EPS_50.27km3km
; WRF.2017090512.EPS_CO.27km3km

; zoom is an integer that determines how far and where to zoom in. High numbers zoom in more. 
; parse /glade/work/ahijevyc/ncl/get_field_res.ncl for region definitions. (e.g. "IRMA_zoom2")

 
begin
    ; Run first with type="avg"
    if(.not.isvar("type"))then
        type = "prob"
    end if
    if(.not.isvar("modelstr"))then
        modelstr = "ECMWF.2017090612"
    end if
    ; this is the part that comes after modelstr and a period '.'
    if(.not.isvar("ensemble_str"))then
        ensemble_str = "ens_" ; could be single digit ensemble member or "CO"
    end if
    if(.not.isvar("stormname"))then
        stormname = "IRMA"
    end if
    if(.not.isvar("stride"))then
        stride=1
    end if
    if(.not.isvar("ncluster"))then
        ncluster = 6
    end if
    if(.not.isvar("cluster_deg"))then
        cluster_deg = 3
    end if
    if(.not.isvar("cluster_start_time"))then
        cluster_start_time = "2017090512"
    end if
    if(.not.isvar("tracks"))then
        tracks = True
    end if
    if(.not.isvar("markers"))then
        markers = False
    end if
    ; basedir used to find maxele.63.nc and fort.22 files.
    basedir = "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+ensemble_str+"/"
    outdir  = "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
    control_str = get_ADCIRC_control_str(modelstr) 
    if(isvar("cluster"))then
        ;members = get_members(cluster, stormname, 7, 5)
        tmp := str_split(modelstr,".")
        init_time = tmp(1)
        ; cluster arguments used for printClusters.csh, directory name, and plot label
        cluster_args = (/init_time, cluster_start_time, tostring(cluster_deg), tostring(ncluster), tostring(cluster) /)
        members  = systemfunc("/glade/u/home/fossell/adcirc/kowaleski/printClusters.csh "+str_join(cluster_args, " "))
        members := str_split(members," ") ; split string into array
        do i = 0, dimsizes(members)-1 ; zero-pad to 2 digits
            do while (strlen(members(i)).lt.2)
                members(i) = "0" + members(i) ; zero-pad single-digit member
            end do
        end do
        basedir := "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+".EPS_"+ members + ".27km3km/"
        outdir  = "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr +".cluster"+str_join(cluster_args, "_") + ".27km3km/"
        if(.not.fileexists(outdir))then
            print(outdir + " does not exist")
            exit
        end if
    end if
    ; zoom level
    if(.not.isdefined("zoom")) then
        zoom = 1
    end if
    ; region - not needed. Just use zoom=2 for FloridaSW
    ;                           use zoom=5 for Tampa
    ;                           use zoom=6 for FloridaNE domain
    if(.not.isvar("minus_astronomical_tide"))then
        minus_astronomical_tide = False
    end if
    if(.not.isvar("elevationlt"))then
        elevationlt = 10.0 ; mask elevations >= this value
    end if
    elevationlt_string = sprintf("%02.0fm", elevationlt)
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


    domainString = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + \
                   sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF)
    cluster_str = ""
    if(isvar("cluster"))then
        cluster_str = ".cluster" + str_join(cluster_args,"_")
    end if
    outfile = outdir+str_sub_str(modelstr,"/",".")+cluster_str+".minus_astronomical_tide"+minus_astronomical_tide+"_"+thresh_string+"."+dryland + \
              "."+sprintf("stride%02.0f.",stride)+domainString+"."+elevationlt_string+"."+type

    ; ECMWF or WRF ensemble or WRF ensemble cluster
    ; basedir may be an array of strings
    members    := systemfunc("ls " + str_join(basedir+"maxele.63.nc", " "))
    trackfiles  = systemfunc("ls " + str_join(basedir+"fort.22"     , " "))
    station_files  := systemfunc("ls " + str_join(basedir+"fort.61.nc", " ")) ; 6-min water height at stations

    ; hwt2017 ensemble
    ;members    = systemfunc("ls "+basedir+"ens_*/latlon_0.125deg_000km/maxele.63.nc")
    ;trackfiles = systemfunc("ls "+basedir+"ens_*/latlon_0.500deg_025km/gfdl_tracker/tracker/IrmaTrack.atcf"  )

    ; uni time-lagged ensemble
    ;members    = systemfunc("ls "+basedir+"latlon_0.125deg_000km/maxele.63.nc")
    ;trackfiles = systemfunc("ls "+basedir+"latlon_0.500deg_025km/gfdl_tracker/tracker/fort.64.IRMA")
    
    ; perturbed ensemble (where modelstr="nws19", or whatever)
    ; ncl 'modelstr="nws19"' 'ensemble_str="veer"' 'type="total"' thresh=1 ../ensemble_avg_plot.ncl

    control = "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+control_str+"/maxele.63.nc"
    f = addfile(control,"r")
    control_inundation = f->zeta_max + f->depth
    ; Set missing values to zero. Don't use num() to count non-missing values (zero is not missing but is not True either).
    control_inundation = where(ismissing(control_inundation),0.,control_inundation)

    ensemble =  addfiles(members, "r")
    print("reading "+sprinti("%d ", dimsizes(members))+" members")
    ListSetType(ensemble, "join")
    f = ensemble[0]
    k = ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)

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
        if(dimsizes(members).gt.1)then
            wgt = new(dimsizes(members), "float")
            wgt = 1.
            x_inundation = 100 * dim_avg_wgt_n_Wrap(break_thresh, wgt, 0, 0) 
        else
            x_inundation = 100 * break_thresh
        end if
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
    x_inundation@long_name = modelstr+ensemble_str+"~C~ensemble " + type + " maximum inundation >="+thresh_string
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
    x_inundation = mask(x_inundation, (-1 * f->depth).lt.elevationlt, True)
    x_inundation@elevationlt = elevationlt_string
    print(num(.not.ismissing(x_inundation))+" inundated nodes after masking elevation >="+elevationlt_string)

    ; Thought about putting this in "prob" block above but wanted to
    ; filter out water points and low-lying points below MHHW 
    control_break_thresh = where(control_inundation.ge.thresh,1,0)
    brier_score = avg((x_inundation(k)/100 - control_break_thresh(k))^2.)
    es_filename = outfile+".nc"
    if(fileexists(es_filename))then
        system("rm " + es_filename)
    end if
    fes = addfile(es_filename, "c")
    fcst := new(dimsizes(k), float)
    fcst!0 = "node"
    fcst = x_inundation(k)/100
    fes->fcst = fcst
    control := new(dimsizes(k), float)
    control!0 = "node"
    control = (/ control_break_thresh(k) /)
    fes->control = control
    filevardef(fes, (/"thresh"/), (/"float"/), "ncl_scalar")
    thresh@units = "m" 
    fes->thresh = thresh
    print("making " + es_filename)
    print(brier_score)


    wtype    = "png"
    wtype@wkWidth  = 2048 
    wtype@wkHeight = 2048 
    wks = gsn_open_wks(wtype,outfile)
    gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
    gsn_define_colormap(wks,"prcp_1")
    cmap = gsn_retrieve_colormap(wks)
    res@gsnSpreadColorStart = 6
    cmap(res@gsnSpreadColorStart,:) = (/1,1,0.999999/)
    res@gsnSpreadColorEnd = 16
    gsn_define_colormap(wks, cmap)
        
    res@sfXArray                 = f->x
    res@sfYArray                 = f->y
    res@sfDataArray              = x_inundation


    res@cnFillOn                 = True
    res@cnLinesOn                = False
    res@cnFillMode               = "RasterFill"
    res@mpOceanFillColor         = "lightcyan" 
    res@mpInlandWaterFillColor   = "lightcyan" 
    res@lbBoxMinorExtentF        = 0.20 ; default .33
    res@lbTitleString            = x_inundation@long_name
    res@lbTitleFontHeightF       = 0.011
    res@lbTitlePosition          = "Bottom"

    ; Don't advance the frame.
    res@gsnFrame = False

    res@gsnStringFontHeightF    = 0.012
    res@mpDataBaseVersion       = "MediumRes" ; "HighRes" has no state borders. "MediumRes" will run faster.
    res@mpLimitMode             = "LatLon"
    res@mpPerimOn               = False
    res@pmTickMarkDisplayMode   = "Always"    ; Turn on map tickmarks.
    lres                        = True
    lres@gsLineThicknessF       =  1.
    lres@gsLineLabelFontHeightF = 0.007

    map := gsn_csm_contour_map(wks,x_inundation,res)

    if(markers)then
        markerfile = "/glade/work/ahijevyc/ADCIRC/IRMA/quantify_locs.csv"
        lines := asciiread(markerfile,-1,"string")
        mlons = tofloat(str_get_field(lines,1,","))
        mlats = tofloat(str_get_field(lines,2,","))
        mlocs = str_get_field(lines,3,",")
        mres = True
        mres@gsMarkerIndex = 16            ; 5=X 16=circle
        mres@gsMarkerSizeF = 5.0           
        mres@gsMarkerColor = (/"black"/)   ; choose color
        mres@txFontHeightF = 0.01
        if(zoom.eq.2)then
            mres@txJust        = "BottomCenter" ; good for SW domain
        end if
        if(zoom.eq.3)then
            mres@txJust        = "TopLeft" ; good for NE domain
        end if
        gsn_polymarker(wks,map,mlons,mlats,mres)
        gsn_text(wks,map,"   "+mlocs+" ",mlons,mlats,mres)
        do imarker=0,dimsizes(lines)-1
            ; find index of closest node.
            ; TODO: use station_files (fort.61.nc) instead? 
            ; If so, convert water height (zeta) to inundation depth.  
            ; 1-deg longitude is smaller than 1-deg latitude by factor of cos(lat).
            dx = (mlons(imarker) - f->x) * cos(f->y)
            dy = mlats(imarker) - f->y
            distance = sqrt(dx^2. + dy^2.)
            inode = minind(distance)
            print(mlocs(imarker)+sprintf(" %4.2f", x_inundation(inode)))
        end do
    end if

    if(tracks)then
        ; draw tracks for all members
        do iveer=0,dimsizes(trackfiles)-1  
            trackfile = trackfiles(iveer)
            ; Assume ens member label follows ensemble_str 
            iens = str_index_of_substr(trackfile,ensemble_str,-1)
            track_label = str_get_cols(trackfile,iens+strlen(ensemble_str),-17) ; ignore ".27km3km/fort.22" at end
            if(fileexists(trackfile))then
                print("reading "+trackfile)
                adeck := read_atcf(trackfile)
                tracklon := adeck@lon
                tracklat := adeck@lat
                lres@gsLineLabelString = track_label
                gsn_polyline(wks,map,tracklon,tracklat,lres)
            end if
        end do
    end if
    
    txres = True
    txres@txFontHeightF = 0.01
    txres@txJust        = "BottomLeft"
    cstr = "domain "+tostring(zoom)+"~C~"+systemfunc("date")
    if(isvar("cluster"))then
        cstr = "cluster " + str_join(cluster_args, " ") + "~C~" + cstr
    end if
    gsn_text_ndc(wks, cstr,0.01,0.01,txres)

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

