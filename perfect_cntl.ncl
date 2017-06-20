load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/p/work/ahijevyc/ADCIRC/get_MHHW.ncl"

begin

    if(.not.isvar("modelstr"))then
        modelstr = "control"
    end if
    if(.not.isvar("stormname"))then
        stormname = "IKE"
    end if
    basedir = "/glade/scratch/ahijevyc/ADCIRC/"
    modeldir = basedir + stormname+"/"+modelstr+"/" 
    obsdir   = basedir + stormname+"/control/" 
    workdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
    ; zoom level
    if(.not.isdefined("zoom")) then
        zoom = 1
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

    outdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
    outfile = outdir+modelstr+".minus_astronomical_tide"+minus_astronomical_tide+".perfectmodel.zoom"+zoom+"."+dryland


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




    res = True
    ; Assign domain min/max lat/lon attributes to res.
    res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

    print("opening "+modeldir+"maxele.63.nc")
    f = addfile(modeldir+"maxele.63.nc","r")

    k = ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)

    obs_file   = "/tmp/"+stormname+  ".control"+".zoom"+zoom+".nc" ; temporary mesh zoomed to lat/lon bounds
    model_file = "/tmp/"+stormname+"."+modelstr+".zoom"+zoom+".nc" ; used later in script
    files = (/ obs_file, model_file /)
    full_files = (/ obsdir, modeldir /) + "maxele.63.nc"

    ; sfc_sub_state was defined in get_MHHW.ncl
    sfc_sub_state := sfc_sub_state(k)
    hgt_MHHW := hgt_MHHW(k)

    ; loop through control (i=0) and model (i=1)
    do i=0,1
        ; Read zeta_max, depth, x, y, and areaCell from full-field file.
        ; Trim domain and derive inundation.
        system("rm -v "+files(i)) 
        g = addfile(files(i),"c")
        f = addfile(full_files(i),"r")
        ; Trim zeta_max, depth, x, y, areaCell to indices where k=True (lat/lon conditions above)
        ; Saved trimmed variables to ncl file variable "g"
        g->zeta_max = f->zeta_max(k)
        g->depth = f->depth(k)
        g->x = f->x(k)
        g->y = f->y(k)
        ; get area asssociated with each node (loaded above with get_MHHW.ncl)
        g->areaCell = areaCell(k)

        ; Max inundation. You can calculate volume but it doesn't make sense. This is a max over time at each point. 
        ; The inundation is never actually this much at any time.  The max water height is spread over time as it washes over the land.
        ; That's why the number here is so much larger than the number in the instantaneous bulge_timeseries. 
        inundation = g->zeta_max + g->depth
        ; Set missing values to zero. Don't use num() to count non-missing values (zero is not missing but is not True either).
        if(any(ismissing(g->zeta_max)))then
            inundation(ind(ismissing(g->zeta_max))) = 0.
        end if
        ; Only retain land values and low-lying land nodes below MSL (sfc_sub_state=1, or "startDry" nodes). 
        inundation = mask(inundation, (g->depth).le.0 .or. (sfc_sub_state.eq.1), True)
        inundation@long_name = "maximum inundation (all times)"
        inundation@units     = "m"
        if(dryland.eq."MHHW")then
            print(num(.not.ismissing(inundation))+" inundated nodes before masking nodes below MHHW=0")
            ; Preserve nodes with missing MHHW (where Vdatum couldn't convert, like over land or deep into Gulf)
            ; or MHHW >= 0 (above normally dry land).
            inundation         = mask(inundation, ismissing(hgt_MHHW).or.hgt_MHHW.ge.0, True)
            print(num(.not.ismissing(inundation))+" inundated nodes after masking nodes below MHHW=0")
        end if
        g->inundation = inundation
    end do

    ; Create stats file that may be plotted by python in Jupyter notebook. 
    if(isfilepresent(outfile+".nc"))then
        system("rm -v "+outfile+".nc")
    end if
    out2 = addfile(outfile+".nc","c")
    
    wks = gsn_open_wks("png",outfile)
    trackfile = modeldir+"fort.22"
    ; fort.22 is quite different for the NOS_OWI run. it don't have lat/lon of track.
    print("reading "+trackfile)
    adeck := read_atcf(trackfile)
    tracklon = adeck@lon
    tracklat = adeck@lat

    f = addfile(model_file,"r")
    nnodes = dimsizes(f->zeta_max) ; number of nodes
    inundation = f->inundation
    zeta_max   = f->zeta_max
    depth      = f->depth
    areaCell  := f->areaCell

    gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
    res@cnLinesOn                = False
    res@cnLevelSelectionMode     = "ManualLevels"
    res@cnMinLevelValF           =  1e-11
    res@cnMaxLevelValF           =  5.
    res@cnLevelSpacingF          =  0.5

    res@sfFirstNodeIndex         = 1
    res@sfXArray                 = f->x
    res@sfYArray                 = f->y
    res@sfDataArray              = inundation


    res@cnFillOn                 = True
    res@cnFillMode               = "RasterFill"
    res@cnLineLabelsOn           = True
    res@cnLineLabelPlacementMode = "Constant"
    res@lbLabelAutoStride        = True
    res@lbTitleString            = "maximum inundation (meters)"
    res@lbTitleFontHeightF       = 0.018
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


    map := gsn_csm_contour_map(wks,inundation,res); attributes matter, but 2nd argument data values have no influence; had to define res@sfDataArray.
    getvalues map@contour ; used in histogram
        "cnLevels" : cnLevels
        "cnFillColors" : cnFillColors
    end getvalues

    txres = True
    txres@txFontHeightF = 0.01
    txres@txJust        = "BottomLeft"
    gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)
    ; Draw a dot on each node.
    noderes                   = True
    noderes@gsMarkerIndex     = 1
    noderes@gsMarkerSizeF     = 0.001
    noderes@gsMarkerOpacityF  = 0.007

    ; Get "observations" from control run.
    print("reading "+obs_file)
    print(model_file)
    g = addfile(obs_file,"r")
    obs = g->inundation
    g = addfile(model_file,"r")
    model=g->inundation
    obsres = True
    obsres@gsMarkerIndex = 16
    obsres@gsMarkerColor = "dark green"
    obsres@gsMarkerSizeF = 0.003
    obsres@gsMarkerThicknessF = 2.
    obsres@txFontHeightF = res@cnLineLabelFontHeightF * 1.5
    obsres@txFontColor = obsres@gsMarkerColor
    obsres@txJust = "CenterLeft"
    if(isdefined("tracklon"))then ; not applicable for NOS_OWI (doesn't use official IKE track)
        storm_track := gsn_add_polyline(wks,map,tracklon,tracklat,lres)
    end if

    tmp := maxind(abs(obs-model))
    print("obs="+tostring(obs(tmp))+" model="+tostring(model(tmp))+" at "+tostring(g->x(tmp))+"E "+tostring(g->y(tmp))+" depth="+tostring(g->depth(tmp))+" sfc_sub_state="+tostring(sfc_sub_state(tmp)))
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
    ; Do we handle missing values in obs and/or model?
    ; For a dry node, zeta_max is missing. A node may be dry in one run & wet in another.
    ; Yes. Above, I replaced missing zeta_max values with zero, so stats
    ; include all points where either the model or obs are wet. 
    print(rc)
    if(rc@nptxy.lt.3)then
        frame(wks)
        print("finished "+outfile)
        exit
    end if
    r := sum((obs-avg(obs))*(model-avg(model)))/stddev(obs)/stddev(model)/(rc@nptxy-1)
    r2 := r^2.
    r2@long_name = "squared Pearson correlation coefficient"
    rmse = sqrt(avg((obs-model)^2))
    si = stddev(obs-model)/avg(obs)
    out2->obs = obs
    out2->model = model
    out2->r2 = r2

    xyres                 = True                   ; plot mods desired
    xyres@gsnDraw         = False
    xyres@gsnFrame        = False
    ; this controls the size and location of the plot
    xyres@vpXF            = 0.70
    xyres@vpWidthF        = 0.20	    
    xyres@vpYF            = 0.96
    xyres@vpHeightF       = 0.20 

    xyres@gsnMaximize         = False                  ; maximize plot in frame
    xyres@xyMarkLineModes     = (/"Markers"/)  ; choose which have markers
    xyres@xyMarker            = obsres@gsMarkerIndex               ; choose type of marker 
    xyres@xyMarkerColor       = "dark green"                ; Marker color
    xyres@xyMarkerSizeF       = obsres@gsMarkerSizeF         ; Marker size (default 0.01)
    xyres@xyMarkerThicknesses   = (/obsres@gsMarkerThicknessF/) 
    xyres@xyDashPatterns      = (/"Solid"/)                
    xyres@xyLineThicknesses   = (/1/) 
    xyres@xyLineColors        = (/xyres@xyMarkerColor/)
    xyres@xyLabelMode         = "Custom"
    xyres@gsnShape            = True
    xyres@trYMinF             = 0.
    xyres@trXMinF             = 0.
    xyres@trYMaxF             = 8.
    xyres@trXMaxF             = 8.

    xyres@tiMainString        = "n="+sprintf("%.0f",rc@nptxy)+", r~S~2~N~="+sprintf("%4.2f",r2)+", multiplic. bias="+sprintf("%4.2f",avg(model)/avg(obs))+"~C~scatter index="+sprintf("%4.2f",si) + ", RMSE="+sprintf("%4.2fm",rmse)
    xyres@tiYAxisString       = modelstr + "~C~" + model@long_name + "~C~(meters)"
    xyres@tiXAxisString       = obs_file + "~C~(meters)"

    plot  = gsn_csm_xy (wks,obs,model,xyres)    ; create scatterplot
    ; Get xrange so lines can be drawn to edges of plot.
    getvalues plot
        "trXMaxF" : xmax
    end getvalues
    xrange = (/ xyres@trXMinF, xmax /)
    xyres@xyExplicitLabels = "best-fit"
    xyres@xyMarkLineMode     = "Lines"
    xyres@xyLineColor        = xyres@xyMarkerColor
    delete(xyres@xyLineColors)
    delete(xyres@xyMarkerThicknesses)
    delete(xyres@xyLineThicknesses)
    delete(xyres@xyMarkLineModes)
    best_fit = gsn_csm_xy(wks, xrange, rc*xrange + rc@yintercept,xyres) 
    xyres@xyExplicitLabels   = "1:1"
    xyres@xyLineColor        = "black"
    one2one  = gsn_csm_xy(wks, xrange, xrange, xyres)
    overlay(plot,best_fit)
    overlay(plot,one2one)
    draw(plot)
    frame(wks)



    print("finished "+outfile)
    
end

