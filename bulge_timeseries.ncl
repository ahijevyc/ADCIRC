load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/p/work/ahijevyc/ncl/cd_inv_string.ncl"
load "/glade/p/work/ahijevyc/ncl/date_str.ncl"
load "/glade/p/work/ahijevyc/ncl/get_length_scale.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/CreateTracks.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/p/work/ahijevyc/ADCIRC/get_MHHW.ncl"

begin

    if(.not.isvar("modelstr"))then
        modelstr = "control"
    end if
    if(.not.isvar("stormname"))then
        stormname = "IRMA"
    end if
    if(.not.isvar("stride"))then
        stride=2
        if(str_get_cols(stormname,-3,-1).eq."IKE")then
            stride=10
        end if
    end if
    basedir = "/glade/p/work/ahijevyc/ADCIRC/"
    modeldir = basedir + stormname+"/"+modelstr+"/"

    ; If True, plot only one frame (default False)
    if(.not.isdefined("one_frame")) then
        one_frame = False
    end if

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

    outdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




    res = True
    ; Assign domain min/max lat/lon attributes to res.
    res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

    left_percentile   = 2.5
    right_percentile = 97.5

    f63 = modeldir+"fort.63.nc"
    print("opening "+f63)
    f = addfile(f63,"r")

    domainString = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + \
                   sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF) + region
    outfile = outdir+modelstr+".minus_astronomical_tide"+minus_astronomical_tide+"_"+thresh_string+"."+dryland + "."+sprintf("stride%02.0f.",stride)+domainString
    iregion = get_iregion(f, region)
    k = ind(iregion .and. f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)
    ; Take every stride-th node (to speed things up).
    k := k(::stride)
    if(any(ismissing(k)))then
        print("no nodes in zoom domain and/or region?")
        printMinMax(f->x,False)
        printMinMax(f->y,False)
        print(res)
        exit
    end if
 
    ; Extract slice of nodes for smaller file
    model_file = modeldir+"fort.63."+sprintf("stride%02.0f.",stride)+domainString
    if(.not.isfilepresent(model_file+".nc")) then
        g = addfile(model_file+".nc","c")
        ; Thin zeta, depth, x, y, and areaCell.
        printVarSummary(f->zeta)
        g->zeta = f->zeta(:,k)
        g->depth = f->depth(k)
        g->x = f->x(k)
        g->y = f->y(k)
        g->areaCell = areaCell(k)

        ;sfc_sub_state was defined in get_MHHW.ncl
        copy_VarCoords(f->depth, sfc_sub_state)
        g->sfc_sub_state = sfc_sub_state(k)
        g->hgt_MHHW = hgt_MHHW(k)
        print("made "+model_file)
    end if

    ; read water height from processed (smaller) file
    print("reading smaller processed file "+model_file+".nc")
    f = addfile(model_file+".nc","r")
    print("png file will be "+outfile)
    wks = gsn_open_wks("png",outfile)
    timeseries_file = outfile + ".timeseries.nc"
    zeta := f->zeta ; read water height from processed (smaller) file
    depth := f->depth
    if(minus_astronomical_tide)then
        ; Subtract water level from run with no storm. Just astronomical tide.
        ; This will give storm surge (the change in water level due to storm).
        a = addfile(modeldir+"../coldstart_extend/fort.63.nc","r")
        surface_height = reshape(-a->depth,dimsizes(a->zeta))
        ; Change missing values in astronomical tide run to surface height (-depth).
        ; now zeta is height of water or land (whichever is higher).
        zeta_nostorm = where(ismissing(a->zeta), surface_height, a->zeta)
        ; Change missing values in storm run to surface height (-depth).
        zeta = where(ismissing(zeta),surface_height(:,k),zeta)
        print("subtracting astronomical tide from storm tide")
        ; Use "k" subscripts to get small slice of zeta_nostorm that matches size and shape of zeta.
        zeta = zeta - zeta_nostorm(:,k)
        zeta@minus_astronomical_tide = minus_astronomical_tide
        zeta@long_name = "storm surge (storm tide minus astronomical tide)"
        print("subtracted astronomical tide")
    end if

    printVarSummary(zeta)
    printMinMax(zeta,False)
    ntime = dimsizes(zeta&time)
    nnodes = dimsizes(depth)
    sfc_sub_state := f->sfc_sub_state
    hgt_MHHW      := f->hgt_MHHW
    areaCell      := f->areaCell

    date_str1 = date_str(f->time)
    print("first adcirc time: "+date_str1(0))

    trackfile = modeldir+"fort.22"
    ; fort.22 is quite different for the NOS_OWI run. it don't have lat/lon of track.
    print("reading "+trackfile)
    adeck := read_atcf(trackfile)
    tracklon = adeck@lon
    tracklat = adeck@lat
    adeck_valid = adeck@valid   
    adeck_valid@units = adeck@timeunits
    tracktime = cd_convert(adeck_valid, f->time@units)
    print("first fort.22 tracktime: "+date_str(tracktime(0)))
    trackheading := adeck@heading
    trackI := sin(trackheading/180.*3.141592)
    trackJ := cos(trackheading/180.*3.141592)
    vmax   := adeck@vmax
    rad    := adeck@rad

    gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
    res@gsnDraw                  = False
    res@gsnFrame                 = False
    res@cnLevelSelectionMode     = "ManualLevels"
    res@cnMinLevelValF           =  1e-11
    res@cnMaxLevelValF           =  5.
    res@cnLevelSpacingF          =  0.5
    ; Tricky color table
    ; get_field_res(wks,'inundation',hgt_MHHW)


    res@vpXF                     =  0.2
    res@vpWidthF                 =  0.6
    res@vpYF                     =  0.57
    res@vpHeightF                =  0.41

    res@sfFirstNodeIndex         = 1
    res@sfXArray                 = f->x
    res@sfYArray                 = f->y
    res@cnFillOn                 = True
    res@cnLinesOn                = False
    res@cnFillMode               = "RasterFill"
    res@cnLineLabelsOn           = True
    res@cnLineLabelPlacementMode = "Constant"
    res@lbLabelAutoStride        = True
    res@lbTitleFontHeightF       = 0.01
    res@lbTitlePosition          = "Bottom"
    res@pmTickMarkDisplayMode    = "Always"    ; Turn on map tickmarks.
    res@mpFillOn                 = False

    storm_center_res := True

    ; Time series panel
    sres                        = True
    sres@gsnFrame               = False
    sres@gsnDraw                = False
    sres@tiMainString           = modelstr + " run,  minus_astronomical_tide=" + minus_astronomical_tide
    sres@xyLineColor            = "black"
    sres@tiYAxisFontHeightF     =  0.013
    sres@xyLineThicknessF       =  3.
    sres@gsnYRefLine            =  0.0
    sres@tmXBLabelFontHeightF   =  0.012
    sres@xyLabelMode            = "Custom"
    sres@xyLineLabelFontHeightF =  0.008
    sres@vpXF                   =  0.2
    sres@vpWidthF               =  0.7
    sres@vpYF                   =  0.9
    sres@vpHeightF              =  0.15
    lres                        = True
    lres@gsLineThicknessF       =  4.

    mres                      = True
    mres@gsMarkerIndex        = "x"
    mres@gsMarkerThicknessF   = 4.
    mres@gsMarkerSizeF        = 0.01

    resTick                = True
    resTick@ttmFormat      = "%hZ %c %d"
    resTick@ttmAxis        = "XB"
    resTick@ttmMajorStride = 48
    resTick@ttmMinorStride = 12
    time_axis_labels(f->time, sres, resTick)
 
    control_timeseries_file := str_sub_str(timeseries_file,modelstr,"control")
    print("control_timeseries_file="+control_timeseries_file)
    if(.not.fileexists(control_timeseries_file).and.modelstr.ne."control")then
        print("didn't find "+control_timeseries_file)
        print("control timeseries file doesn't exist yet. make it.")
    end if
    c := addfile(control_timeseries_file,"r")

    ; If timeseries file doesn't exist, create it and initialize variables. Otherwise preserve them.
    if(isfilepresent(timeseries_file))then
        g = addfile(timeseries_file,"w")
        inundation_volume = g->inundation_volume
        inundation_true = g->inundation_true
        length_scale    = g->length_scale; read previously written array
        volume_in_ctrl  = g->volume_in_ctrl ; 
        average_depth   = g->average_depth
        inundation_area = g->inundation_area
    else
        g = addfile(timeseries_file,"c")
        ; Put res variable in global attributes so we have lat/lon min/max
        globalAtts = True
        globalAtts@domain = domainString
        globalAtts@minus_astronomical_tide =  minus_astronomical_tide
        globalAtts@stride = stride
        globalAtts@zoom = zoom
        globalAtts@region = region
        fileattdef(g, globalAtts)
        inundation_volume = new(ntime,double,-999.); need short number for titles (default is minus 1 zillion billion)
        inundation_volume@long_name = "inundation volume in inundation zone"
        inundation_volume@units = "km~S~3~N~"
        inundation_volume@stride = stride
        inundation_volume@depth_threshold = thresh_string
        inundation_volume@left_percentile = left_percentile
        inundation_volume@right_percentile = right_percentile
        inundation_volume!0 = "time"
        inundation_volume&time = zeta&time
        g->inundation_volume = inundation_volume

        average_depth = new(dimsizes(inundation_volume),typeof(inundation_volume))
        copy_VarMeta(inundation_volume, average_depth)
        average_depth@long_name = "average depth in inundation zone"
        average_depth@units = "m"
        average_depth@stride = stride
        g->average_depth=average_depth

        inundation_area = new(dimsizes(inundation_volume),typeof(inundation_volume))
        copy_VarMeta(inundation_volume, inundation_area)
        inundation_area@long_name = "area of inundation zone"
        inundation_area@units = "km~S~2~N~"
        inundation_area@stride = stride
        g->inundation_area=inundation_area

        inundation_true = new((/ntime,nnodes/),byte)
        copy_VarAtts(inundation_volume, inundation_true)
        inundation_true@long_name = "1b=inundated"
        inundation_true@stride = stride
        inundation_true!0="time"
        inundation_true&time = zeta&time
        inundation_true!1="node"
        g->inundation_true = inundation_true

        length_scale = new(dimsizes(inundation_volume),typeof(inundation_volume))
        copy_VarMeta(inundation_volume, length_scale)
        length_scale@long_name = "length_scale of inundation zone"
        length_scale@units = "km"
        length_scale@stride = stride
        g->length_scale = length_scale

        volume_in_ctrl = new(dimsizes(inundation_volume),typeof(inundation_volume))
        copy_VarMeta(inundation_volume, volume_in_ctrl)
        volume_in_ctrl@long_name = "inundation volume in control inundation zone"
        g->volume_in_ctrl=volume_in_ctrl

    end if

    tmp := dimsizes(inundation_true)
    if(tmp(1).ne.nnodes)then
        printVarSummary(inundation_true)
        print(nnodes)
        print("Number of nodes doesn't match")
        print("Remove "+timeseries_file+" and rerun with stride="+tostring(stride)+"?")
        exit
    end if

    ; meta data for sanity check
    txres = True
    txres@txFontHeightF = 0.01
    txres@txJust        = "BottomLeft"

    ; Dot nodes 
    noderes                  = True
    noderes@gsMarkerColor    = "pink"
    noderes@gsMarkerIndex    = 1
    noderes@gsMarkerSizeF    = 0.005
    noderes@gsMarkerOpacityF = 0.9

    ; Draw LS contours (left and right sides)
    LSres = True
    LSres@gsnDraw = False
    LSres@gsnFrame = False
    LSres@cnLevelSelectionMode = "ExplicitLevels"
    LSres@cnExplicitLineLabelsOn = True
    LSres@cnLineLabelBackgroundColor = -1
    LSres@cnLineLabelInterval = 1
    LSres@sfFirstNodeIndex = res@sfFirstNodeIndex
    LSres@sfXArray = res@sfXArray
    LSres@sfYArray = res@sfYArray
    LSres@cnInfoLabelString = "length scale $CMN$ to $CMX$ km"
    ;LSres@cnLevelSelectionMode = "AutomaticLevels" ; plot a bunch of contours

    ; define itime to just plot the time with maximum bulge volume
    ; assumes time series is complete already
    itime = maxind(inundation_volume)
    if(ismissing(itime))then
        itime=235
    end if

    first_frame = True
    do itime=0,ntime-1,1
        ; Vertical line at current time
        sres@gsnXRefLine = f->time(itime)
        sres@gsnRightString = date_str1(itime) 
        print(date_str(f->time(itime)))

        ; Get current lat/lon of storm, interpolating fort.22
        ; Find first track time later than frame time, tracki
        tracki = min(ind(tracktime .ge. f->time(itime)))
        if(rad(tracki).ne.34.and.rad(tracki).ne.0)then
            ; sanity check; tracki should correspond to a rad=34kt line and tracki-1 to a 34, 50, or 64kt line.
            ; This was true for Ike, but not Charley, in Charley there are 0kt lines (with no accompanying 34kt lines).
            print("unexpected wind intensity threshold in fort.22 file")
            print(tostring(rad(tracki)))
            print(date_str(tracktime(tracki)))
            exit
        end if
        ; Get time interval between tracki and tracki-1 and fraction of time past by frame time
        frac = tofloat((f->time(itime) - tracktime(tracki-1)) / (tracktime(tracki)-tracktime(tracki-1)))
        tracklat0 = (1 - frac) * tracklat(tracki-1) + frac * tracklat(tracki)
        tracklon0 = (1 - frac) * tracklon(tracki-1) + frac * tracklon(tracki)
        vmax0     = (1 - frac) * vmax(tracki-1)     + frac * vmax(tracki) 
        ; trackJ0 and trackI0 are vector components of heading
        trackJ0   = (1 - frac) * trackJ(tracki-1)   + frac * trackJ(tracki) + tracklat0
        trackI0   = (1 - frac) * trackI(tracki-1)   + frac * trackI(tracki) + tracklon0
        dist := gc_latlon(res@sfYArray,res@sfXArray,conform(res@sfYArray,tracklat0,-1),conform(res@sfXArray,tracklon0,-1),2,-4)
        expand_plots_deg = 2. ; expand plot-worthy locations by expand_plots_deg (except for south boundary)
        if(tracklon0 .lt. (res@mpMinLonF-expand_plots_deg) .or. \
           tracklon0 .gt. (res@mpMaxLonF+expand_plots_deg) .or. \
           tracklat0 .lt.  res@mpMinLatF         .or. \
           tracklat0 .gt. (res@mpMaxLatF+expand_plots_deg) )then
            print(sprintf("%6.1fE,", tracklon0) + sprintf("%5.1fN", tracklat0)+" storm outside domain. skipping.")
            continue
        end if
        lat :=  transpose( (/ onedtond(tracklat0,dimsizes(res@sfYArray)), onedtond(trackJ0,dimsizes(res@sfYArray)), res@sfYArray /) )
        lon :=  transpose( (/ onedtond(tracklon0,dimsizes(res@sfXArray)), onedtond(trackI0,dimsizes(res@sfXArray)), res@sfXArray /) )
        LorR := gc_dangle(lat,lon)
        dist_right = dist * -sin(LorR/180.*3.141592)
        zeta1 := zeta(itime,:)

        if(.not.minus_astronomical_tide)then
            ; inundation is water height minus surface height (depth is negative surface height)
            inundation = zeta1 + depth
            copy_VarMeta(zeta1, inundation)
            inundation@long_name = "depth of water over normally dry land ("+dryland+">=0)"
        else
            inundation = zeta1
            ; Plot storm surge (minus_astronomical_tide=True).
            res@sfDataArray    = inundation
            map := gsn_csm_contour_map(wks,inundation,res)
        end if

        res@lbTitleString  = inundation@units

        ; Limit volume to Surge Zone

        ; Mask ocean
        ; In other words, mask all nodes with depth>0, but not start-dry nodes.
        ; sfc_sub_state is missing or 1. 1 is land that starts dry but depth>0 (is below MSL). 
        inundation = mask(inundation, depth.le.0 .or. sfc_sub_state.eq.1, True)
        print(num(.not.ismissing(inundation))+" inundated (=>0) nodes")

        if(dryland.eq."MHHW")then
            ; Don't consider nodes below the mean higher high water mark as normally dry. Mask them.
            ; Use MHHW to mask nodes, but don't apply mask where MHHW is missing. This happens where(where Vdatum couldn't convert, like over land or deep into Gulf)
            ; or MHHW >= 0 (above normally dry land).
            inundation = mask(inundation, ismissing(hgt_MHHW).or.hgt_MHHW.ge.0, True)
            print(num(.not.ismissing(inundation))+" inundated nodes after masking nodes below MHHW=0")
        end if

        if(.not.minus_astronomical_tide)then
            ; Plot inundation (minus_astronomical_tide=False).
            ; If minus_astronomical_tide=True, storm surge has already been plotted above.
            res@sfDataArray    = inundation
            map := gsn_csm_contour_map(wks,inundation,res)
        end if

        volume = areaCell * inundation/1000. * stride
        ; added thresh threshold Feb 23, 2016. only count nodes where inundation exceeds this depth.
        ; Set volumes to zero where inundation depth is less than threshold.
        ; This affects length scale, average depth, total inundation volume, inundation area...
        printMinMax(inundation,False)
        
        volume = where(.not.ismissing(inundation).and.inundation.ge.thresh,volume,0.) 
        tmp := maxind(volume)
        print("node with greatest inundation volume (area*inundation): areaCell="+tostring(areaCell(tmp))+\
            "sq km, inundation="+\
            tostring(inundation(tmp))+"m, "+tostring(res@sfXArray(tmp))+"E "+tostring(res@sfYArray(tmp))+"N")
        if(sum(volume).eq.0)then
            print("no inundation above threshold. skipping time.")
            continue
        end if

        left_length_km  = get_length_scale(volume,dist_right, left_percentile/100.)
        right_length_km = get_length_scale(volume,dist_right, right_percentile/100.)
        g->length_scale(itime) = right_length_km - left_length_km
        ; Draw LS contours (left and right sides)
        LSres@cnLevels = (/ left_length_km, right_length_km /)
        LSres@cnLineLabelStrings = (/ "Left: "+sprintf("%.0fkm",left_length_km), "Right: "+sprintf("%.0fkm",right_length_km) /)
        LS := gsn_csm_contour(wks, dist_right, LSres)
        overlay(map, LS)
        print("overlaid length scale")

        ; Highlight "beach" nodes i.e. >= LMSL but below < MHHW
        bi := ind((depth.le.0.or.sfc_sub_state.eq.1).and.hgt_MHHW.lt.0)
        if(.not.any(ismissing(bi)))then
            ; Draw pink dots
            ; dots := gsn_add_polymarker(wks,map,res@sfXArray(bi),res@sfYArray(bi),noderes)
        end if

        ; .gt.0. used to be .ge.0, but we don't want dry land nodes
        bi := ind(dist_right.ge.left_length_km.and.dist_right.le.right_length_km.and.volume.gt.0.)
        if(.not.any(ismissing(bi)))then
            inundation_volume(itime) = sum(volume(bi))
            g->inundation_volume(itime) = (/ inundation_volume(itime) /)
            g->average_depth(itime) = sum(inundation(bi)*areaCell(bi))/ sum(areaCell(bi))
            g->inundation_area(itime) = sum(areaCell(bi)) * stride
            ; remember to reset zeroes or else you get 1's from previous runs.
            g->inundation_true(itime,:) = 0b
            g->inundation_true(itime,bi) = 1b
        end if

        ; Tried gsnLeftString resource but it wouldn't update the resource on the map object after I created map.
        desc = sprintf("inundation zone defined by %.0f",right_percentile-left_percentile)+"% of volume (" +sprintf("%.1f",left_percentile)+"% to the left and "+sprintf("%.1f",100.-right_percentile)+"% to the right) where depth >= "+thresh_string
        desc = desc +"~C~inundation zone volume " + sprintf(":%6.2f", inundation_volume(itime)) + inundation_volume@units + "   length:" + sprintf("%4.0fkm",right_length_km-left_length_km) + "   average depth: " + sprintf("%.1fm",g->average_depth(itime)) + "    area: "+ sprintf("%.0f km~S~2~N~",g->inundation_area(itime)) + "~C~normally-dry land datum=" + dryland

        ; Inundated nodes in control run.
        ; If you get error about file (c) isn't defined, just run again.
        icontrol := ind(c->inundation_true(maxind(c->inundation_volume),:).eq.1)
        if(.not.any(ismissing(icontrol)))then
            volume_in_ctrl(itime) = sum(volume(icontrol))
            if(one_frame)then
                ; Draw pink dots
                dots := gsn_add_polymarker(wks,map,res@sfXArray(icontrol),res@sfYArray(icontrol),noderes)
                desc = desc + "~C~inundation zone volume intersecting inundation zone of control run (pink): " + sprintf("%6.2fkm~S~3~N~",volume_in_ctrl(itime))
            end if
        end if
        gsn_text_ndc(wks, desc, 0.204, 0.63, txres)

        ; Use (/ /) to avoid creating degenerate (1-element) dimensions like 'ncl137'
        g->volume_in_ctrl(itime) = (/ volume_in_ctrl(itime) /)

        if(.not.first_frame.and.one_frame)then
            print("not drawing this frame")
            continue
        end if
        first_frame = False

        storm_track := gsn_add_polyline(wks,map,tracklon,tracklat,lres)
        print("added storm track")


        fracts := (/ 0.99, 0.95, 0.9, 0.8, 0.7, 0.5 /)
        do i=0,-1; dimsizes(fracts)-1
            ; Don't redefine left and right_percentile here. That will mess up the global values.
            ; Same with left_length_km and right_length_km
            xleft_length_km  = get_length_scale(volume,dist_right,  fracts(i)/2.)
            xright_length_km = get_length_scale(volume,dist_right, 1.-fracts(i)/2.)
            LSres@cnLevels = (/ xleft_length_km, xright_length_km /)
            LSres@cnLineLabelStrings = (/ "Left: "+sprintf("%.0fkm",xleft_length_km), "Right: "+sprintf("%.0fkm",xright_length_km) /)
            LS := gsn_csm_contour(wks, dist_right, LSres)
            overlay(map, LS)
        end do

        storm_center_res@gsMarkerIndex = create_tropical_symbol(wks,tracklat0,vmax0)
        storm_center := gsn_add_polymarker(wks,map,tracklon0,tracklat0,storm_center_res)
        vmax_res = True
        vmax_res@txFontHeightF = 0.02
        vmax_res@txFontOpacityF = 0.7
        storm_center_vmax := gsn_add_text(wks,map,sprintf("%.0fkt",vmax0),tracklon0,tracklat0,vmax_res)

        draw(map)
        print("draw(map) completed")
        ; Dot at station of interest
        sres@xyLineColor          = "dark green"
        y1 := inundation_volume
        sres@xyExplicitLabels     = "inun da tion" ; spaces allow label to bend around tight curves
        delete(map)
        ; check for 2 unique values. avoid error about zero width y axis
        if (count_unique_values(y1).ge.2)then
            ; Important to use := with xy_plot or memory use will grow to > 5GB.
            xy_plot := gsn_csm_xy(wks,f->time,y1,sres)
            draw(xy_plot)
            delete(xy_plot)
        else
            print(date_str(f->time(itime))+": did not find > 2 unique values for y axis")
        end if
        ; meta data for sanity check
        ; for some reason putting systemfunc("date") in the do loop resulted in random crashes
        currentdate = systemfunc("date")
        gsn_text_ndc(wks,date_str(f->time(itime)) +\
            sprinti("~C~every %.0i nodes",stride)+\
            "~C~made " + currentdate,0.01,0.01,txres)
        frame(wks)
    end do
    
end
