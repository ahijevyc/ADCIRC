load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/work/ahijevyc/ADCIRC/get_MHHW.ncl" ; get hgt_MHHW, areaCell, sfc_sub_state
load "/glade/work/ahijevyc/ADCIRC/minus_astronomical_tide.ncl"

; Compare maximum inundation depth in control and perturbed runs.

; Max over time.
; You can't calculate volume cause it doesn't make sense.
; This is a max over time at each point. 
; The inundation is never actually this much at any time.  
; The max water height is spread over time as it washes over the land.
; That's why the number here is so much larger than in the instantaneous bulge_timeseries. 

; Both perfect_cntl.ncl and bulge_timeseries.ncl can subtract astronomical tide.
; The prodedure is complicated and I would like to do it the same way, but I don't. 
; If you find something wrong with the way it is done in one of them, make sure you 
; fix the other one too.



begin

    if(.not.isvar("modelstr"))then
        modelstr = "control"
    end if
    if(isStrSubset(modelstr,"/"))then
        print("modelstr can't have subdirectories. make modelstr a long string with parts instead")
        exit
    end if

    if(.not.isvar("stormname"))
        stormname = "IRMA"
    end if
    if(.not.isvar("stride"))then
        stride=1
    end if
    basedir = "/glade/work/ahijevyc/ADCIRC/"
    modeldir = basedir + stormname+"/"+modelstr+"/"
    control_str = "control"
    ; if you change this here, change in inundation_timeseries.ncl also.
    if(isStrSubset(modelstr,"nws19")\
        .or.isStrSubset(modelstr,"coldstart")\
        .or.isStrSubset(modelstr,".ecic"))then
        control_str = "nws19.control"
    end if
    if(isStrSubset(modelstr,"nws20")\
        .or.isStrSubset(modelstr,"ECMWF")\
        .or.isStrSubset(modelstr,"EPS"))then
        if(isStrSubset(modelstr,"2017090512"))then
            control_str = "nws20.control_newtides_2017090512"
        end if
        if(isStrSubset(modelstr,"2017090812"))then
            control_str = "nws20.control_newtides_2017090812"
        end if
    end if
    obsdir   = str_sub_str(modeldir,modelstr,control_str)
    csedir   = str_sub_str(modeldir,modelstr,"coldstart_extend")

    ; zoom level
    if(.not.isdefined("zoom")) then
        zoom = 1
    end if
    ; region
    if(.not.isdefined("region")) then
        region = ""
    end if
    if(.not.isvar("minus_astronomical_tide"))then
        minus_astronomical_tide = False
    end if
    if(.not.isvar("thresh"))then
        thresh = 1.0 ; inundation threshold
    end if
    thresh_string = sprintf("%4.2fm", thresh)
    if(.not.isvar("dryland"))then
        ; Baseline for normally-dry land LMSL>=0 or MHHW>=0
        dryland= "MHHW" ; or "LMSL" 
    end if
    ; Sanity check for misspelled dryland
    if(.not.any(dryland.eq.(/"MHHW","LMSL"/)))then
        print("Unexpected dryland: "+dryland)
        exit
    end if

    outdir = "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




    res = True
    ; Assign domain min/max lat/lon attributes to res.
    res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

    f63 = modeldir+"maxele.63.nc"
    print("opening perturbation zeta_max "+f63)
    f = addfile(f63,"r")

    domainString = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + \
                   sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF) + region
    outfile = outdir+modelstr+".minus_astronomical_tide"+minus_astronomical_tide+"_"+thresh_string+"."+dryland + \
              "."+sprintf("stride%02.0f.",stride)+domainString+".perfectmodel"
    iregion = get_iregion(f, region, res)
    k = ind(iregion .and. f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)
    
    tmpdir = "/glade/scratch/"+getenv("USER")+"/temp/"
    uniqid = systemfunc("echo $$")
    obs_file   = tmpdir + stormname+"."+uniqid+".control.zoom"+zoom+".nc" ; temporary mesh zoomed to lat/lon bounds
    model_file = tmpdir + stormname+"."+uniqid+".perturb.zoom"+zoom+".nc" ; used later in script (used to be modelstr, but doesn't work when modelstr=control)
    cse_file   = tmpdir + stormname+"."+uniqid+".cse.zoom"    +zoom+".nc" ; Coldstart extend could be used later in script
    files = (/ obs_file, model_file/)
    full_files = (/ obsdir, modeldir/) + "maxele.63.nc"

    if(any(ismissing(k)))then
        print("no nodes in zoom domain and/or region?")
        printMinMax(f->x,False)
        printMinMax(f->y,False)
        print(res)
        exit
    end if
    if(minus_astronomical_tide)then
        ; Aside - How to subtract tide from max water over time?
        ;  Do you create a "difference" time series first
        ; and then find the maximum? Or just subtract zeta_max's? This script does the latter. 
        files      := array_append_record(files, cse_file, 0)
        full_files := array_append_record(full_files, csedir + "maxele.63.nc", 0)
    end if
    ; sfc_sub_state was defined in get_MHHW.ncl
    copy_VarCoords(f->depth, sfc_sub_state)
    sfc_sub_state := sfc_sub_state(k)
    hgt_MHHW      := hgt_MHHW(k)


    ; Loop through 3 files first and trim to domain
    ; 1) control (i=0)
    ; 2) perturbed (i=1)
    ; 3) coldstart_extend (i=2)
    ; Remember trimmed coldstart_extend (cse) for later.
    do i=0,dimsizes(files)-1
        ; Read zeta_max, depth, x, and y from full-field file.
        ; Trim domain and derive inundation.
        system("rm -v "+files(i)) 
        g = addfile(files(i),"c")
        print("opening "+full_files(i)+" for reading")
        f = addfile(full_files(i),"r")
        ; Trim zeta_max, depth, x, y, areaCell to indices where k=True (lat/lon conditions above)
        ; Saved trimmed variables to ncl file variable "g"
        g->zeta_max = f->zeta_max(k)
        g->depth    = f->depth(k)
        g->x        = f->x(k)
        g->y        = f->y(k)
        ; get area asssociated with each node (loaded above with get_MHHW.ncl)
        g->areaCell = areaCell(k)
        if(i.eq.2)then
            ; coldstart_extend (tide-only)
            cse = g->zeta_max
        end if
    end do
    ; Just loop thru control (i=0) and perturbed (i=1) and subtract cse if requested.
    ; Calculate inundation.
    do i=0,1
        print("addfile for writing "+files(i))
        g = addfile(files(i),"w")

        if(minus_astronomical_tide)then
            ; Same procedure in minus_astronomical_tide.ncl.
            solid_ground_height = -g->depth
            ; Change missing values in storm run to solid ground height.
            zeta         = where(ismissing(g->zeta_max), solid_ground_height, g->zeta_max) 
            ; Change missing values in coldstart_extend run to solid ground height.
            zeta_nostorm = where(ismissing(cse), solid_ground_height, cse)
            ; Subtract astronomical tide from storm tide.
            inundation = zeta - zeta_nostorm
        else
            inundation = g->zeta_max + g->depth
            ; Set missing values to zero. Don't use num() to count non-missing values (zero is not missing but is not True either).
            if(any(ismissing(g->zeta_max)))then
                inundation(ind(ismissing(g->zeta_max))) = 0.
            end if
        end if


        ; Retain land nodes (negative or zero depth) and "startDry" nodes (sfc_sub_state=1).
        ; "startDry" nodes start dry, but are below MSL (positive depth).
        inundation = mask(inundation, (g->depth).le.0 .or. (sfc_sub_state.eq.1), True)
        inundation@long_name = "maximum inundation (all times)"
        inundation@units     = "m"
        if(dryland.eq."MHHW")then
            print(num(.not.ismissing(inundation))+" inundated nodes before masking nodes below MHHW=0")
            ; Preserve nodes with missing MHHW (where Vdatum couldn't convert, like over land or deep into Gulf)
            ; or MHHW >= 0 (above normally dry land).
            inundation       = mask(inundation, ismissing(hgt_MHHW).or.hgt_MHHW.ge.0, True)
            print(num(.not.ismissing(inundation))+" inundated nodes after masking nodes below MHHW=0")
        end if
        g->inundation = inundation
    end do

    ; Create stats file that may be plotted by python in Jupyter notebook. 
    if(fileexists(outfile+".nc"))then
        system("rm -v "+outfile+".nc")
    end if
    out2 = addfile(outfile+".nc","c")
    
    wtype    = "png"
    wtype@wkWidth  = 2048 
    wtype@wkHeight = 2048 
    wks = gsn_open_wks(wtype,outfile)
    trackfile = modeldir+"fort.22"
    ; fort.22 is quite different for the NOS_OWI run. it don't have lat/lon of track.
    print("reading "+trackfile)
    adeck := read_atcf(trackfile)
    tracklon = adeck@lon
    tracklat = adeck@lat

    print("reading perturbed file "+model_file)
    f = addfile(model_file,"r")
    nnodes = dimsizes(f->zeta_max) ; number of nodes

    gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
    res@cnLevelSelectionMode     = "ManualLevels"
    res@cnMinLevelValF           =  1e-09
    res@cnMaxLevelValF           =  2.0
    res@cnLevelSpacingF          =  0.2

    res@sfXArray                 = f->x
    res@sfYArray                 = f->y
    res@sfDataArray              = f->inundation

    res@cnFillOn                 = True
    res@cnLinesOn                = False
    res@cnFillMode               = "RasterFill"
    res@cnLineLabelsOn           = True
    res@cnLineLabelPlacementMode = "Constant"
    res@lbLabelAutoStride        = True
    res@lbTitleString            = "maximum inundation (meters)"
    res@lbTitleFontHeightF       = 0.01
    res@lbTitlePosition          = "Bottom"

    res@gsnCenterString          = modelstr
    res@gsnCenterStringOrthogonalPosF = 0.1
    res@gsnRightString           = ""

    ; Don't advance the frame.
    res@gsnFrame = False

    res@pmTickMarkDisplayMode = "Always"    ; Turn on map tickmarks.
    res@cnConstFLabelOn       = False ; don't say "CONSTANT FIELD - VALUE IS 0"
    lres                      = True
    lres@gsLineThicknessF     =  4.


    map := gsn_csm_contour_map(wks,f->inundation,res); attributes matter, but 2nd argument data values have no influence; had to define res@sfDataArray.
    getvalues map@contour ; used in histogram
        "cnLevels" : cnLevels
        "cnFillColors" : cnFillColors
    end getvalues

    ; Annotate plot with domain info and creation date.
    txres = True
    txres@txFontHeightF = 0.01
    txres@txJust        = "BottomLeft"
    gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)

    ; Draw a dot on each node.
    noderes                  = True
    noderes@gsMarkerColor    = "pink"
    noderes@gsMarkerIndex    = 1
    noderes@gsMarkerSizeF    = 0.001
    noderes@gsMarkerOpacityF = 0.09

    ; Get "observations" from control run.
    print("reading control file "+obs_file)
    g = addfile(obs_file,"r")
    obs   = g->inundation
    model = f->inundation
    obsres = True
    obsres@gsMarkerIndex = 16
    obsres@gsMarkerColor = "dark green"
    obsres@gsMarkerSizeF = 0.004
    obsres@gsMarkerThicknessF = 2.
    obsres@txFontColor = obsres@gsMarkerColor
    obsres@txJust = "CenterLeft"

    if(isdefined("tracklon"))then ; not applicable for NOS_OWI (doesn't use official IKE track)
        storm_track := gsn_add_polyline(wks,map,tracklon,tracklat,lres)
        draw(map) ; lres@gsnDraw=True did not work
    end if

    tmp := maxind(abs(obs-model))
    print("obs="+tostring(obs(tmp))+" model="+tostring(model(tmp))+" at "+\
          tostring(g->x(tmp))+"E "+tostring(g->y(tmp))+" depth="+tostring(g->depth(tmp))+\
          " sfc_sub_state="+tostring(sfc_sub_state(tmp)))
    printVarSummary(obs)
    printMinMax(obs,False)
    printVarSummary(model)
    printMinMax(model,False)
    if(num(.not.ismissing(obs)).ne.num(.not.ismissing(model)))then
        print("obs != model points")
        print(num(.not.ismissing(obs)))
        print(num(.not.ismissing(model)))
        exit
    end if
    rc = regCoef(obs, model); regCoef and regline return slope of best-fit line
    ; If a node does not get wet at all during the run, zeta_max is missing. 
    ; Do we handle missing values in obs and/or model? Yes.
    ; Above, we treated missing value as zero inundation.
    ; Therefore, stats include all normally-dry nodes, as specified by "dryland".
    print(rc)
    if(rc@nptxy.lt.3)then
        frame(wks)
        print("finished "+outfile)
        exit
    end if
    if(stddev(model).gt.0.)then
        r := sum((obs-avg(obs))*(model-avg(model)))/stddev(obs)/stddev(model)/(rc@nptxy-1)
    else
        r := new(1,float)
    end if
    ; Sanity check. Make sure r is unity for control.
    if(.not.ismissing(str_index_of_substr(modelstr,"control",1)))then
        if(abs(r-1).gt.0.00001)then
            print("If this is the control, r should be 1 (within machine precision)")
            print(r)
            exit
        end if
    end if
    r2 := r^2.
    r2@long_name = "squared Pearson correlation coefficient"
    rmse = sqrt(avg((obs-model)^2))
    scatterindex = stddev(obs-model)/avg(obs)
    out2->obs = obs
    out2->model = model
    out2->r2 = r2
    out2@full_files = full_files

    xyres                 = True                   ; plot mods desired
    xyres@gsnDraw         = False
    xyres@gsnFrame        = False
    ; this controls the size and location of the plot
    xyres@vpXF            = 0.77
    xyres@vpWidthF        = 0.16	    
    xyres@vpYF            = 0.97
    xyres@vpHeightF       = 0.16 

    xyres@gsnMaximize         = False                       ; maximize plot in frame
    xyres@xyMarkLineMode      = "Markers"                   ; choose which have markers
    xyres@xyMarker            = obsres@gsMarkerIndex        ; choose type of marker 
    xyres@xyMarkerColor       = "dark green"                ; Marker color
    xyres@xyMarkerSizeF       = 0.002; obsres@gsMarkerSizeF ; Marker size (default 0.01)
    xyres@xyMarkerThicknessF  = obsres@gsMarkerThicknessF 
    xyres@xyDashPattern       = "Solid"               
    xyres@xyLineThicknessF    = 1 
    xyres@xyLineColor         = xyres@xyMarkerColor
    xyres@xyLabelMode         = "Custom"
    xyres@gsnShape            = True
    ; can have negative "storm" surge
    xyres@trYMinF             = -0.5
    xyres@trXMinF             = -0.5
    xyres@trYMaxF             = 5.
    xyres@trXMaxF             = 5.


    xyres@tiMainString        = "n="+sprintf("%.0f",rc@nptxy)+", r~S~2~N~="+sprintf("%4.2f",r2)+", multiplic. bias="+sprintf("%4.2f",avg(model)/avg(obs))+"~C~scatter index="+sprintf("%4.2f",scatterindex) + ", RMSE="+sprintf("%4.2fm",rmse)
    xyres@tiYAxisString       = modelstr + "~C~" + model@long_name + "~C~(meters)"
    xyres@tiXAxisString       = obs_file + "~C~(meters)"

    plot  = gsn_csm_xy (wks,obs,model,xyres)    ; create scatterplot
    ; Get xrange so lines can be drawn to edges of plot.
    getvalues plot
        "trXMaxF" : xmax
    end getvalues
    xrange = (/ xyres@trXMinF, xmax /)
    bfres = True
    bfres@gsnDraw            = False
    bfres@gsnFrame           = False
    bfres@xyLabelMode        = "Custom"
    bfres@xyLineLabelFontHeightF = 0.02
    bfres@xyExplicitLabels = "best-fit"
    bfres@xyMarkLineMode     = "Lines"
    bfres@xyLineColor        = xyres@xyMarkerColor
    bfres@xyLineThicknessF   = 2.0
    best_fit = gsn_csm_xy(wks, xrange, rc*xrange + rc@yintercept,bfres) 
    bfres@xyExplicitLabels   = "1:1"
    bfres@xyLineColor        = "black"
    one2one  = gsn_csm_xy(wks, xrange, xrange, bfres)
    overlay(plot,best_fit)
    overlay(plot,one2one)
    draw(plot)
    frame(wks)



    print("finished "+outfile)
    
end
