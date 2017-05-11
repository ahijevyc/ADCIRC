load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/p/work/ahijevyc/ncl/cd_inv_string.ncl"
load "/glade/p/work/ahijevyc/ncl/date_str.ncl"
load "/glade/p/work/ahijevyc/ncl/get_length_scale.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/CreateTracks.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"

begin
	; for some reason putting systemfunc("date") in the do loop resulted in random crashes
	currentdate = systemfunc("date")
	if(.not.isvar("modelstr"))then
		modelstr = "control"
	end if
	if(.not.isvar("stormname"))then
		stormname = "MATTHEW"
	end if
	if(.not.isvar("stride"))then
		stride=2
		if(stormname.eq."IKE")then
			stride=10
		end if
	end if
	idir   = "/glade/scratch/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/" 
	workdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
	; zoom level
	if(.not.isdefined("zoom")) then
		zoom = 1
	end if
	if(.not.isvar("minus_astronomical_tide"))then
		minus_astronomical_tide = False
	end if

	res = True
	res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

	left_percentile   = 2.5
	right_percentile = 97.5
	thresh = 1.0 ; inundation threshold
	thresh_string = sprintf("%4.2fm", thresh)

	f63 = idir+"fort.63.nc"
	print("opening "+f63)
	f = addfile(f63,"r")

	LabelFontHeightF    =   0.0
	domainString = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF)

	k =   ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)
	k := k(::stride)
	if(any(ismissing(k)))then
		print("no nodes in zoom domain?")
		printMinMax(f->x,False)
		printMinMax(f->y,False)
		print(res)
		exit
	end if
 
	; Extract slice of nodes for smaller file
	sm_fort63 = workdir+"fort.63."+sprintf("stride%02.0f.",stride)+domainString
	if(.not.isfilepresent(sm_fort63+".nc")) then
		g = addfile(sm_fort63+".nc","c")
		; Thin zeta, depth, x, y, and areaCell.
		printVarSummary(f->zeta)
		g->zeta = f->zeta(:,k)
		g->depth = f->depth(k)
		g->x = f->x(k)
		g->y = f->y(k)
		a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/NOS_cells.nc","r")
		g->areaCell = a->areaCell(k)

		; Read file that lists nodes where surface submergence state is 1
		sfc_sub_state_file = "/glade/p/work/ahijevyc/ADCIRC/surface_submergence_state_14040.txt"
		lines = asciiread(sfc_sub_state_file, -1, "integer")
		; asciiread() reads into a 1-D array. the file is 2 columns, so read every other one, starting with element zero 
		; to get the first column. These are the inodes. 
		inodes = lines(::2)
		; Create a new variable to hold the surface submergence state.
		sfc_sub_state = new(dimsizes(f->depth), "integer")
		; Set appropriate inodes to 1
		; The sfc_sub_state_file lists node indices where indices are 1-based.  But ncl is zero-based.  So subtract one from the node indices.
		sfc_sub_state(inodes-1) = 1
		g->sfc_sub_state = sfc_sub_state(k)
		print("made "+sm_fort63)
	end if

    ; Model time series interpolated to observation lat/lon
    g = addfile(idir+"fort.61.nc","r")
    station_time = g->time
    station_name = str_strip(tostring(g->station_name))
    istation = ind(station_name .eq. "8768094")
    station_lon = g->x(istation)
    station_lat = g->y(istation)
    station_lon = -93.3430
    station_lat =  29.7680
    station_zeta = g->zeta(:,istation)
    ; model station_time is every 6 minutes (not same as f->time)
    ;print("interpolating model station time (every 6 min) to f->time")
    ;station_zetas = int2p_Wrap(station_time, station_zeta, f->time, 1)

	; read water height from processed (smaller) file
	f = addfile(sm_fort63+".nc","r")
	outfile := workdir+modelstr+".minus_astronomical_tide"+minus_astronomical_tide+"_"+thresh_string
	print("opening "+outfile)
	wks = gsn_open_wks("png",outfile)
	timeseries_file = outfile + "."+sprintf("stride%02.0f.",stride)+domainString+".timeseries.nc"
	zeta := f->zeta ; read water height from processed (smaller) file
	if(minus_astronomical_tide)then
		;print("subtracting astronomical tide from model station time series")
		;g := addfile(idir+"../coldstart_extend/fort.61.nc","r")
		;station_zeta_tide = g->zeta
		;station_zeta = station_zeta - station_zeta_tide(:,istation)
        ;station_zeta@minus_astronomical_tide = minus_astronomical_tide
		a = addfile(idir+"../coldstart_extend/fort.63.nc","r")
        ; Change missing values in astronomical tide run to zeros.
		zeta_nostorm = where(ismissing(a->zeta),0,a->zeta)
		print("subtracting astronomical tide from model water level")
        ; Use "k" subscripts to get small slice of zeta_nostorm that matches size and shape of zeta.
		zeta = zeta - zeta_nostorm(:,k)
        zeta@minus_astronomical_tide = minus_astronomical_tide
		print("subtracted tide")
	end if

	station_obs_file = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/observations/CO-OPS__8768094__wl.csv"
    print("looking for "+station_obs_file)
	if(fileexists(station_obs_file))then
		lines := asciiread(station_obs_file, -1, "string")
		delim = ","
		DateTimeObs =         str_get_field(lines,1,delim)
		WaterLevel  = tofloat(str_get_field(lines,2,delim))
		Quality     =         str_get_field(lines,8,delim)
	    station_obs_time = cd_inv_string(DateTimeObs, "%Y-%N-%D %H:%M")
		print("interpolating observed station water level to f->time")
		station_obs = int2p_Wrap(station_obs_time, WaterLevel, f->time, 1)
	end if

	trackfile = idir+"fort.22"
	print("reading "+trackfile)
    
	adeck := read_atcf(trackfile)
	tracklon = adeck@lon
	tracklat = adeck@lat
    adeck_valid = adeck@valid   
    adeck_valid@units = adeck@timeunits
	tracktime = cd_convert(adeck_valid, f->time@units)
	trackheading := adeck@heading
	trackI := sin(trackheading/180*3.141592)
	trackJ := cos(trackheading/180*3.141592)
	vmax   := adeck@vmax
	rad    := adeck@rad

	ntime = dimsizes(zeta&time)
	depth = f->depth
	nnodes = dimsizes(depth)
	sfc_sub_state := f->sfc_sub_state

	date_str1 = date_str(f->time)
	Re = 6371.; radius of Earth in km
	areaCell := f->areaCell * Re^2. * stride

	gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
	res@gsnDraw                  = False
	res@gsnFrame                 = False
	res@cnLevelSelectionMode     = "ManualLevels"
	res@cnMinLevelValF           =  1e-11
	res@cnMaxLevelValF           =  5.
	res@cnLevelSpacingF          =  0.5
	if(False)then ; Tricky color table
		gsn_define_colormap(wks,"StepSeq25")
		gsn_reverse_colormap(wks)
		res@gsnSpreadColorStart = 7
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@lbLabelAutoStride = False
		res@cnLevels =     (/    0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.2, 1.4, 1.6, 1.8,  2,  2.5,  3,  4,  5 /)
		res@lbLabelStrings = (/ "0.1", "",  "", "", "0.5", "", "",  "",  "", "1", "",  "", "",   "", "2","2.5","3","4","5"/)
	end if


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
	res@cnLineLabelFontHeightF   = LabelFontHeightF
	res@lbLabelAutoStride        = True
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
	sres@tmXBLabelFontHeightF   =  0.015
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
	resTick@ttmFormat      = "%d %c"
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
        fileattdef(g, globalAtts)
		inundation_volume = new(ntime,double,-999.); need short number for titles (default is minus 1 zillion billion)
		inundation_volume@long_name = "inundation volume in surge zone"
		inundation_volume@units = "km~S~3~N~"
		inundation_volume@depth_threshold = thresh_string
		inundation_volume@left_percentile = left_percentile
		inundation_volume@right_percentile = right_percentile
		inundation_volume!0 = "time"
		inundation_volume&time = zeta&time
		g->inundation_volume = inundation_volume

		average_depth = new(dimsizes(inundation_volume),typeof(inundation_volume))
		copy_VarMeta(inundation_volume, average_depth)
		average_depth@long_name = "average depth in surge zone"
		average_depth@units = "m"
		g->average_depth=average_depth

		inundation_area = new(dimsizes(inundation_volume),typeof(inundation_volume))
		copy_VarMeta(inundation_volume, inundation_area)
		inundation_area@long_name = "area of surge zone"
		inundation_area@units = "km~S~2~N~"
		g->inundation_area=inundation_area

		inundation_true = new((/ntime,nnodes/),byte)
		copy_VarAtts(inundation_volume, inundation_true)
		inundation_true@long_name = "1b=inundated"
		inundation_true!0="time"
		inundation_true&time = zeta&time
		inundation_true!1="node"
		g->inundation_true = inundation_true

		length_scale = new(dimsizes(inundation_volume),typeof(inundation_volume))
		copy_VarMeta(inundation_volume, length_scale)
		length_scale@long_name = "length_scale of surge zone"
		length_scale@units = "km"
		g->length_scale = length_scale

        volume_in_ctrl = new(dimsizes(inundation_volume),typeof(inundation_volume))
		copy_VarMeta(inundation_volume, volume_in_ctrl)
        volume_in_ctrl@long_name = "inundation volume in control surge zone"
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
	txres@txJust  = "BottomLeft"

    ; Dot nodes 
    ssres                  = True
    ssres@gsMarkerColor    = "pink"
    ssres@gsMarkerIndex    = 1
    ssres@gsMarkerSizeF    = 0.005
    ssres@gsMarkerOpacityF = 0.5

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
		ring_km = 800.
        ; accurate calculation (great-circle distance)
		dist := gc_latlon(res@sfYArray,res@sfXArray,conform(res@sfYArray,tracklat0,-1),conform(res@sfXArray,tracklon0,-1),2,-4)
		if(min(dist).gt.ring_km)then
			print("storm outside domain. skipping.")
			continue
		end if
		lat :=  transpose( (/ onedtond(tracklat0,dimsizes(res@sfYArray)), onedtond(trackJ0,dimsizes(res@sfYArray)), res@sfYArray /) )
		lon :=  transpose( (/ onedtond(tracklon0,dimsizes(res@sfXArray)), onedtond(trackI0,dimsizes(res@sfXArray)), res@sfXArray /) )
		LorR := gc_dangle(lat,lon)
		dist_right = dist * -sin(LorR/180.*3.141592)
		zeta1 := zeta(itime,:)

		; inundation is water height above MSL minus surface height above MSL (depth is negative for positive height above MSL)
		inundation = zeta1 + depth
		copy_VarMeta(zeta1, inundation)
		inundation@long_name = "depth of water over normally dry land"
		; Isolate start dry land. Mask ocean, but not low-lying land nodes below mean sea level.
		; sfc_sub_state is missing or 1. 1 is land that starts dry but depth>0 (is below MSL). 
		inundation         = mask(inundation, depth.le.0 .or. sfc_sub_state.eq.1, True)
		res@sfDataArray    = inundation
	    res@lbTitleFontHeightF = 0.01
	    res@lbTitlePosition = "Bottom"
	    res@lbTitleString  = inundation@units
		map := gsn_csm_contour_map(wks,inundation,res)

		; Tried to use gsn_polymarker procedure but dots would be overlaid by filled contours.
		volume = areaCell * inundation/1000. ; areaCell has already been multiplied by stride
		; added thresh threshold Feb 23, 2016. only count nodes where inundation exceeds this depth.
		; Set volumes to zero where inundation depth is less than threshold.
		; This affects length scale, average depth, total inundation volume, inundation area...
		printMinMax(inundation,False)
		volume = where(.not.ismissing(inundation).and.inundation.ge.thresh,volume,0.) 
		tmp := maxind(volume)
		print("max inundation node in domain: areaCell="+tostring(areaCell(tmp))+"sq km, inundation="+tostring(inundation(tmp))+"m, "+tostring(res@sfXArray(tmp))+"E "+tostring(res@sfYArray(tmp))+"N")
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

		; .gt.0. used to be .ge.0, but we don't want dry land nodes
		bi := ind(dist_right.ge.left_length_km.and.dist_right.le.right_length_km.and.volume.gt.0.)
		if(.not.any(ismissing(bi)))then
			inundation_volume(itime) = sum(volume(bi))
			g->inundation_volume(itime) = (/ inundation_volume(itime) /)
			g->average_depth(itime) = sum(inundation(bi)*areaCell(bi))/ sum(areaCell(bi))
			g->inundation_area(itime) = sum(areaCell(bi)) ; areaCell has already been multiplied by stride
			; remember to reset zeroes or else you get 1's from previous runs.
			g->inundation_true(itime,:) = 0b
			g->inundation_true(itime,bi) = 1b
			; Draw (pink) dots 
			;dots := gsn_add_polymarker(wks,map,res@sfXArray(bi),res@sfYArray(bi),ssres)
		end if
	
		; IKE coordinates in control run.
		icontrol := ind(c->inundation_true(maxind(c->inundation_volume),:).eq.1)
		if(.not.any(ismissing(icontrol)))then
			volume_in_ctrl(itime) = sum(volume(icontrol))
			; Draw (pink) dots 
			;dots := gsn_add_polymarker(wks,map,res@sfXArray(icontrol),res@sfYArray(icontrol),ssres)
		end if
		; Use (/ /) to avoid creating degenerate (1-element) dimensions like 'ncl137'
		g->volume_in_ctrl(itime) = (/ volume_in_ctrl(itime) /)

		if(.not.first_frame)then
			;print("not drawing this frame")
			;continue
		end if
		first_frame = False



		; tried to use gsnLeftString resource but it wouldn't update the resource on the map object after I created map.
		title := sprintf("~C~surge zone defined by %.0f",right_percentile-left_percentile)+"% of volume (" +sprintf("%.1f",left_percentile)+"% to the left and "+sprintf("%.1f",100.-right_percentile)+"% to the right) where depth >= "+thresh_string+"~C~surge zone volume " + sprintf(":%6.2f", inundation_volume(itime)) + inundation_volume@units + " / length:" + sprintf("%4.0fkm",right_length_km-left_length_km) + " average depth: " + sprintf("%.1fm",g->average_depth(itime)) + " / area: "+ sprintf("%.0f km~S~2~N~",g->inundation_area(itime)) + "~C~surge zone volume intersecting surge zone of control run (pink): " + sprintf("%6.2fkm~S~3~N~",volume_in_ctrl(itime))
		gsn_text_ndc(wks,title, 0.204, 0.6, txres)
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
		sres@xyExplicitLabels     = "inun da tion"
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
		gsn_text_ndc(wks,date_str(f->time(itime)) +\
			sprinti("~C~every %.0i nodes",stride)+\
			"~C~made " + currentdate,0.01,0.01,txres)
		frame(wks)
	end do
	
end
; multi-panel movie
;foreach f (`seq -f '%06.0f' 1 347`)
;foreach? montage -trim -geometry 80% control.tide.$f.png control.bulge.$f.png NOS.tide.$f.png NOS.bulge.$f.png $f.png
;foreach? end
;convert -adjoin ??????.png -loop 0 -delay 80 t.gif


