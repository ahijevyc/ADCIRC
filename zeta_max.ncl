load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/work/ahijevyc/ADCIRC/get_MHHW.ncl";get hgt_MHHW, areaCell, sfc_sub_state, get_ADCIRC_control_str

; Compare maximum inundation heights at nearest model point and observed point.

begin

    if(.not.isvar("modelstr"))then
        modelstr = "nws20.control.2018100700"
    end if
    if(.not.isvar("stormname"))then
        stormname = "Michael2018"
    end if
    if(.not.isvar("stride"))then
        stride=1
    end if
    basedir = "/glade/work/ahijevyc/ADCIRC/"
    modeldir = basedir + stormname+"/"+modelstr+"/"
    obsdir   = basedir + stormname+"/observations/"
    ; ike_SSS_high_water.csv created by get_USGS_high_water.csh from pubs.usgs.gov/of/2008/1365/downloads
    obs_file = obsdir + stormname+"_SSS_high_water.csv"
    obs_file = obsdir + "HWMs.Event287.nc"
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
    if(.not.isvar("elevationlt"))then
        elevationlt = 10.0 ; mask elevations >= this value
    end if
    elevationlt_string = sprintf("%02.0fm", elevationlt)
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
        print("Expected MHHW or LMSL")
        exit
    end if

    outdir = "/glade/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




    res = True
    ; Assign domain min/max lat/lon attributes to res.
    res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

    f63 = modeldir+"maxele.63.nc"
    print("opening perturbation zeta_max "+f63)
    maxele_fh = addfile(f63,"r")

    domainString = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + \
                   sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF) + region
    outfile = obsdir+modelstr+".minus_astronomical_tide"+minus_astronomical_tide+"_"+thresh_string+"."+dryland + \
              "."+sprintf("stride%02.0f.",stride)+domainString+"."+elevationlt_string +".zeta_max"
    iregion = get_iregion(maxele_fh, region, res)
    k = ind(iregion .and. maxele_fh->x .ge.res@mpMinLonF.and.maxele_fh->x .le.res@mpMaxLonF.and.maxele_fh->y .ge.res@mpMinLatF.and.maxele_fh->y .le.res@mpMaxLatF)
    
    temporary_cropped_model_file = obsdir + "tmp."+stormname+"."+modelstr+".zoom"+zoom+".nc" ; temporary small grid
    if(fileexists(temporary_cropped_model_file))then 
        system("rm -v "+temporary_cropped_model_file)
    end if
    g = addfile(temporary_cropped_model_file,"c")
    g->zeta_max = maxele_fh->zeta_max(k)
    g->depth = maxele_fh->depth(k)
    g->x = maxele_fh->x(k)
    g->y = maxele_fh->y(k)
    ; get area asssociated with each node (loaded with get_MHHW.ncl)
    g->areaCell = areaCell(k)
    ; sfc_sub_state was defined in get_MHHW.ncl
    copy_VarCoords(maxele_fh->depth, sfc_sub_state)
    sfc_sub_state := sfc_sub_state(k)
    hgt_MHHW      := hgt_MHHW(k)

    ; Max inundation. You can calculate volume but it doesn't make sense. This is a max over time at each point. 
    ; The inundation is never actually this much at any time.  The max water height is spread over time as the peak washes inland.
    ; That's why the number here is so much larger than the number in the instantaneous bulge_timeseries. 
    inundation = g->zeta_max + g->depth
    ; Set missing values to zero. Don't use num() to count non-missing values (zero is not missing but is not True either).
    if(any(ismissing(g->zeta_max)))then
        inundation(ind(ismissing(g->zeta_max))) = 0.
    end if
    ; Only retain land values and low-lying land nodes below MSL (sfc_sub_state=1, or "startDry" nodes). 
    inundation = mask(inundation, (g->depth).le.0 .or. (sfc_sub_state.eq.1), True)
    inundation@long_name = "maximum inundation at any time"
    inundation@units     = "m"
    if(dryland.eq."MHHW")then
        print(num(.not.ismissing(inundation))+" inundated nodes before masking nodes below MHHW=0")
        ; Preserve nodes with missing MHHW (where Vdatum couldn't convert, like over land or deep into Gulf)
        ; or MHHW >= 0 (above normally dry land).
        inundation         = mask(inundation, ismissing(hgt_MHHW).or.hgt_MHHW.ge.0, True)
        print(num(.not.ismissing(inundation))+" inundated nodes after masking nodes below MHHW=0")
    end if
    inundation = mask(inundation, (-1 * g->depth).lt.elevationlt, True)
    inundation@elevationlt = elevationlt_string
    print(num(.not.ismissing(inundation))+" inundated nodes after masking elevation >="+elevationlt_string)
    g->inundation = inundation

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

    print("reading cropped adcirc file "+temporary_cropped_model_file)
    f = addfile(temporary_cropped_model_file,"r")
    nnodes = dimsizes(f->zeta_max) ; number of nodes
    inundation = f->inundation
    zeta_max   = f->zeta_max
    depth      = f->depth
    areaCell  := f->areaCell

    gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
    res@cnLinesOn                = False
    res@cnLevelSelectionMode     = "ManualLevels"
    res@cnMinLevelValF           =  1e-09
    res@cnMaxLevelValF           =  4.
    res@cnLevelSpacingF          =  0.25

    res@sfFirstNodeIndex         = 1
    res@sfXArray                 = f->x
    res@sfYArray                 = f->y
    res@sfDataArray              = zeta_max; inundation

    res@cnFillOn                 = True
    res@cnFillMode               = "RasterFill"
    res@cnLineLabelsOn           = True
    res@cnLineLabelPlacementMode = "Constant"
    res@lbBoxMinorExtentF        = 0.20 ; default .33
    res@lbLabelAutoStride        = True
    res@lbTitleFontHeightF       = 0.011
    res@lbTitlePosition          = "Bottom"

    res@gsnStringFontHeightF     = 0.015 
    res@gsnCenterString          = str_sub_str(modelstr, ".", "~C~")
    res@gsnCenterStringOrthogonalPosF = 0.13
    res@gsnCenterStringParallelPosF = 0.07
    res@gsnRightString           = ""

    ; Don't advance the frame.
    res@gsnFrame = False

    res@pmTickMarkDisplayMode = "Always"    ; Turn on map tickmarks.
    lres                      = True
    lres@gsLineThicknessF     =  4.



    dist_threshs = (/500, 250, 100/)
    ;do id = 0, dimsizes(dist_threshs)-1 
    ;    dist_thresh = dist_threshs(id)

    dist_thresh = 500
    res@lbTitleString            = "maximum water height above geoid (m), node < "+sprintf("%4.0fm",dist_thresh)

    map := gsn_csm_contour_map(wks,zeta_max,res); attributes matter, but 2nd argument data values have no influence; had to define res@sfDataArray.
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
    noderes@gsMarkerIndex    = 1
    noderes@gsMarkerSizeF    = 0.001
    noderes@gsMarkerOpacityF = 0.09

    ; Get "observations".
    hardcoded = True
    if(hardcoded)then
        obs_file = obsdir + "googleSheet.nc"
        print("reading 'observations' file "+obs_file)
        g = addfile(obs_file,"r")
        obs         = tofloat(g->obs)
        x           = tofloat(g->longitude)
        y           = tofloat(g->latitude)
        quality_id  = obs
        quality_id  = 1
        stid        = g->id
    else
        print("reading 'observations' file "+obs_file)
        g = addfile(obs_file,"r")
        feet_to_meters = 0.3048
        obs         = g->elev_ft * feet_to_meters
        obs@_FillValue = -9999.
        ; xarray.DataSet.to_netcdf() made _FillValue NaN
        ; this caused problems for NCL because NaN did not 
        ; evaluate to missing. Needed to test is_ieeenan() which is a pain.
        ; Just change _FillValue to -9999. and replace IEEE NaNs with it.
        replace_ieeenan(obs, obs@_FillValue, 0)
        agl         = g->height_above_gnd * feet_to_meters
        x           = g->longitude
        y           = g->latitude
        quality_id  = g->hwm_quality_id
        stid        = g->site_no
    end if
    obsres = True
    obsres@gsMarkerIndex = 16
    obsres@gsMarkerColor = "dark green"
    obsres@gsMarkerSizeF = 0.004
    obsres@gsMarkerThicknessF = 2.
    obsres@txFontColor = obsres@gsMarkerColor
    obsres@txJust = "CenterCenter"
    obsres@txFontHeightF = 0.006
    ; nice black outline around filled circle
    outline_circle_res = True
    outline_circle_res@gsMarkerIndex = 4
    outline_circle_res@gsMarkerSizeF = obsres@gsMarkerSizeF

    if(isdefined("tracklon"))then ; not applicable for NOS_OWI (doesn't use official IKE track)
        storm_track := gsn_add_polyline(wks,map,tracklon,tracklat,lres)
        draw(map) ; lres@gsnDraw=True did not work
    end if
   
    ; Create array to hold distance errors, one value for each observation.
    dist_errs = new(dimsizes(lines),"double")
    dist_errs@long_name = "distance from observation to closest node"
    dist_errs@units = "m"

    model     = new(dimsizes(obs),"double")
    ; for each surge station observation
    do n = 0, dimsizes(obs)-1
        lonlatstr = sprintf("%9.4fE",x(n))+sprintf("%8.4fN",y(n))
        if(ismissing(x(n)).or.ismissing(y(n)).or.x(n).lt.res@mpMinLonF.or.x(n).gt.res@mpMaxLonF.or.y(n).lt.res@mpMinLatF.or.y(n).gt.res@mpMaxLatF)then
            ; skip if observation is out of bounds
            print(lonlatstr + " out of bounds. Skipping")
            obs(n) = obs@_FillValue
            continue
        end if
        if(ismissing(obs(n)))then
            print("obs "+tostring(n)+" is missing. Skipping.")
            obs(n) = obs@_FillValue
            continue
        end if
        if(isnan_ieee(obs(n)))then
            print("obs "+tostring(n)+" is IEEE NaN. Skipping.")
            obs(n) = obs@_FillValue
            continue
        end if
        ;if(gtype(n).ne."surge site")then
        ;    print("Not a surge site. Skipping "+gtype(n))
        ;    continue
        ;end if
        ; Find closest node to surge station
        iu := -4; return the distance in kilometers; negative denotes longitudes -180 to 180.
        ;dist = gc_latlon(res@sfYArray,res@sfXArray,onedtond(y(n),dimsizes(res@sfYArray)),onedtond(x(n),dimsizes(res@sfXArray)),2,iu)
        dist = gc_latlon(res@sfYArray,res@sfXArray,conform(res@sfYArray,y(n),-1),conform(res@sfXArray,x(n),-1),2,iu)
        i = minind(dist)
        ; skip if quality_id is poor or worse
        ; HWM quality code.  Current possibilities:
        ;1 Excellent: +/- 0.05 ft
        ;2 Good: +/- 0.10 ft
        ;3 Fair: +/- 0.20 ft
        ;4 Poor: +/- 0.40 ft
        ;5 VP: > 0.40 ft
        ;6 Unknown/Historical
        if(.not.ismissing(quality_id(n)))then
            if(quality_id(n).ge.4)then
                print("quality_id="+sprintf("%.0f",quality_id(n))+lonlatstr+sprintf("%4.0fkm",dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i))+" n="+sprintf("%4.0f",n)+" obs="+sprintf("%4.1fm",obs(n))+" Ignoring observation")
                obs(n) = obs@_FillValue
                continue
            end if
        end if
        if(dist(i).gt.dist_thresh/1000.)then
            print(lonlatstr+sprintf("%4.0fm",1000*dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i)) + " n="+sprintf("%4.0f",n)+" obs="+sprintf("%4.1fm",obs(n))+" model="+sprintf("%4.1fm",model(n))+" closest node too far")
            continue
        end if
        dist_errs(n) = 1000*dist(i)
        model(n) = zeta_max(i)
        ; If zeta_max is missing don't ignore the point--assign sfc elevation. 
        ; Treat it as zero inundation.
        ; This is a problem for points along small rivers not resolved in ADCIRC mesh.
        ; They have USGS obs of water but NOS mesh land is high and dry.
        ; WARNING there are nodes with missing zeta_max and positive depth, like 401-ILA-03-060
        ; Allow model(n) to be missing if this is the case.
        if(ismissing(zeta_max(i)).and.depth(i).le.0)then
            model(n) = -depth(i)
        end if
        print("obs"+tostring(n)+": "+" "+sprintf("%5.2fm ",obs(n))+lonlatstr+" model:"+sprintf("%5.2fm", model(n)))
        if(ismissing(zeta_max(i)).and.depth(i).gt.0)then
            print(lonlatstr+sprintf("%4.0fkm",dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i)))
            print(sprintf("%9.4fE",res@sfXArray(i))+sprintf("%8.4fN",res@sfYArray(i))+sprintf("%4.0fkm",dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i)))
            print("n="+sprintf("%4.0f",n)+" obs="+sprintf("%4.1fm",obs(n))+" model="+sprintf("%4.1fm",model(n))+" depth="+sprintf("%6.3fm",depth(i)))
        end if
        if(.not.ismissing(model(n)).and.abs(model(n)-obs(n)).gt.5)then
            print(lonlatstr+sprintf("%4.0fm",1000.*dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i))+" depth="+sprintf("%6.2fm",depth(i)))
            print("n="+sprintf("%4.0f",n)+" obs="+sprintf("%5.2fm",obs(n))+" model="+sprintf("%5.2fm",model(n))+" quality="+sprintf("%.0f",quality_id(n)))
        end if
        ; draw dot (NhlTmarkerIndex=1) on node
        gsn_polymarker(wks,map,res@sfXArray(i),res@sfYArray(i),noderes)
        ; Mark observation
        obsres@gsMarkerColor = get_color_index(gsn_retrieve_colormap(wks),cnLevels, obs(n))
        gsn_polymarker(wks,map,x(n),y(n),obsres)
        gsn_polymarker(wks,map,x(n),y(n),outline_circle_res)
        gsn_text(wks,map,stid(n)+sprintf("~C~%5.2f",obs(n)),x(n),y(n),obsres)
    end do
    print("maximum distance from observation: "+sprintf("%5.0fm",max(dist_errs)))

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
    ; Sanity check. Make sure r is unity for control.
    if(.not.ismissing(str_index_of_substr(modelstr,"control",1)))then
        if(abs(r-1).gt.0.00001)then
            print("If this is the control, r should be 1 (within machine precision)")
            print(r)
        end if
    end if
    r2 := r^2.
    r2@long_name = "squared Pearson correlation coefficient"
    rmse = sqrt(avg((obs-model)^2))
    scatterindex = stddev(obs-model)/avg(obs)
    out2->obs = obs
    out2->model = model
    out2->r2 = r2

    xyres                 = True                   ; plot mods desired
    xyres@gsnDraw         = False
    xyres@gsnFrame        = False
    ; this controls the size and location of the plot
    xyres@vpXF            = 0.67
    xyres@vpWidthF        = 0.23	    
    xyres@vpYF            = 0.963
    xyres@vpHeightF       = 0.23

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
    xyres@tiYAxisString       = str_sub_str(modelstr, ".", "~C~") + "~C~" + zeta_max@long_name + "~C~(meters)"
    xyres@tiXAxisString       = obs_file + "~C~(meters)"

    plot  = gsn_csm_xy (wks,obs,model,xyres)    ; create scatterplot
    ; Get xrange so lines can be drawn to edges of plot.
    getvalues plot
        "trXMaxF" : xmax
    end getvalues
    xrange = (/ xyres@trXMinF, xmax /)
    bfres                      = True
    bfres@gsnDraw              = False
    bfres@gsnFrame             = False
    bfres@xyLabelMode          = "Custom"
    bfres@xyLineLabelFontHeightF = 0.01
    bfres@xyExplicitLabels     = "best-fit"
    bfres@xyMarkLineMode       = "Lines"
    bfres@xyLineColor          = xyres@xyMarkerColor
    bfres@xyLineLabelFontColor = xyres@xyMarkerColor
    bfres@xyLineThicknessF     = 2.0
    best_fit = gsn_csm_xy(wks, xrange, rc*xrange + rc@yintercept,bfres) 
    o2ores = bfres
    o2ores@xyLineLabelFontHeightF = 0.02
    o2ores@xyExplicitLabels    = "1:1"
    o2ores@xyLineColor         = "black"
    o2ores@xyLineLabelFontColor = "black"
    one2one  = gsn_csm_xy(wks, xrange, xrange, o2ores)
    overlay(plot,best_fit)
    overlay(plot,one2one)
    draw(plot)
    frame(wks)

    ; Scatterplot on frame of its own.
    xyres@gsnMaximize         = True                  ; maximize plot in frame
    plot  = gsn_csm_xy (wks,obs,model,xyres)    ; create scatterplot
    gsn_text(wks,plot,stid,obs, model,obsres)
    overlay(plot,best_fit)
    overlay(plot,one2one)
    draw(plot)
    gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)
    frame(wks)

    volumes = areaCell/1000.*inundation
    res@sfDataArray      = inundation
    res@lbTitleString    = inundation@long_name + " " + inundation@units
    title = "inundation swath volume = "+sprintf("%.1f", sum(volumes))+" km~S~3~N~"
    map := gsn_csm_contour_map(wks,inundation,res)


    ; Histogram
    hres                 = True
    hres@gsnFrame        = False
    hres@vpXF            = xyres@vpXF
    hres@vpWidthF        = xyres@vpWidthF
    hres@vpYF            = xyres@vpYF
    hres@vpHeightF       = xyres@vpHeightF
    hres@gsnHistogramBinIntervals = cnLevels
    hres@gsnHistogramMinMaxBinsOn = True
    hres@tmLabelAutoStride = True ; avoid overlapping labels
    hres@trYMaxF         = 1.1*num(inundation.ge.0.5.and.inundation.lt.1)
    hres@gsFillColor              = cnFillColors
    plot := gsn_histogram(wks,inundation,hres)
    gsn_text_ndc(wks, "domain "+tostring(zoom)+" "+title+"~C~"+systemfunc("date"),0.01,0.01,txres)
    frame(wks)
    ;plot := gsn_histogram(wks,dist_errs,hres)
    ;end do ; dist_thresh loop

    print("finished "+outfile)
    
end
