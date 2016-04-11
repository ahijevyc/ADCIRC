load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "/glade/p/work/ahijevyc/ncl/date_str.ncl"
load "/glade/p/work/ahijevyc/ncl/get_length_scale.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/CreateTracks.ncl"

begin
	; for some reason putting systemfunc("date") in the do loop resulted in random crashes
	currentdate = systemfunc("date")
	if(.not.isvar("modelstr"))then
		modelstr = "control"
	end if
	if(.not.isvar("stride"))then
		stride=2
	end if
	if(.not.isvar("stormname"))then
		stormname = "CHARLEY"
	end if
	idir = "/glade/scratch/fossell/ADCIRC/"+stormname+"/"+modelstr+"/" 
	if(stormname.eq."IKE")then
		idir = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/"+modelstr+"/" 
	end if
	workdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
	; zoom level
	if(.not.isdefined("zoom")) then
		zoom = 2
	end if
	if(.not.isvar("notide"))then
		; if notide, modelstr has to be "coldstart_extend" one time - you will get an error but dont worry
		notide = False
	end if

	res = True
	res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

	left_percentile   = 2.5
	right_percentile = 97.5
	thresh = 1. ; inundation threshold
	thresh_string = sprintf("%4.2fm", thresh)

	f = addfile(idir+"fort.63.nc","r")

	LabelFontHeightF    =   0.0
	domain_string = sprintf("%.1fE", res@mpMinLonF) + sprintf("%.1fE", res@mpMaxLonF) + sprintf("%.1fN", res@mpMinLatF) + sprintf("%.1fN", res@mpMaxLatF)

	k = ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)
	k := k(::stride)
 
	; cut out needed nodes for smaller file
	sm_fort63 = workdir+"fort.63."+sprintf("stride%02.0f.",stride)+domain_string
	if(.not.isfilepresent(sm_fort63+".nc")) then
		system("rm -vf "+sm_fort63+".nc") 
		g = addfile(sm_fort63+".nc","c")
		; Thin zeta, depth, x, y, and areaCell.
		g->zeta = f->zeta(:,k)
		g->depth = f->depth(k)
		g->x = f->x(k)
		g->y = f->y(k)
		a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/adcirc_Ike_tri_mesh.nc","r")
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
	print("interpolating model station time (every 6 min) to f->time")
	station_zetas = int2p_Wrap(station_time, station_zeta, f->time, 1)

	f = addfile(sm_fort63+".nc","r")
	outfile := workdir+modelstr+".notide"+notide+"_"+thresh_string
	print("opening "+outfile)
	wks = gsn_open_wks("png",outfile)
	timeseries_file = outfile + "."+sprintf("stride%02.0f.",stride)+domain_string+".timeseries.nc"
	zeta := f->zeta
	if(notide)then ; toggle to plot surge time series with astronomical tide removed.
		print("subtracting tide")
		g := addfile(idir+"../coldstart_extend/fort.61.nc","r")
		station_zeta_tide = g->zeta
		station_zeta = station_zeta - station_zeta_tide(:,istation)
		a = addfile(idir+"../coldstart_extend/fort.63.nc","r")
		zeta_nostorm = where(ismissing(a->zeta),0,a->zeta)
		zeta = zeta - zeta_nostorm(:,k)
		print("subtracted tide")
	end if

	station_obs_file = "./"+stormname+"/observations/CO-OPS__8768094__wl.csv"
	if(fileexists(station_obs_file))then
		lines := asciiread(station_obs_file, -1, "string")
		delim = ","
		DateTimeObs =         str_get_field(lines,1,delim)
		WaterLevel  = tofloat(str_get_field(lines,2,delim))
		Quality     =         str_get_field(lines,8,delim)
		year  = tointeger(str_get_cols(DateTimeObs, 0, 3))
		month = tointeger(str_get_cols(DateTimeObs, 5, 6))
		day   = tointeger(str_get_cols(DateTimeObs, 8, 9))
		hour  = tointeger(str_get_cols(DateTimeObs,11,12))
		minute= tointeger(str_get_cols(DateTimeObs,14,15))
		second=minute
		second=0
		; There is a bug in cd_inv_calendar. Use ut_inv_calendar.
		; See https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=4&ved=0CDUQFjADahUKEwjzrKzsy7_IAhUW-2MKHR3FBKE&url=http%3A%2F%2Fmailman.ucar.edu%2Fpipermail%2Fncl-talk%2F2015-July%2F003428.html&usg=AFQjCNHat_z7xtV2q_LT817CbN7e6avfWQ
		station_obs_time = ut_inv_calendar(year, month, day, hour, minute, second, station_time@units, 0)
		print("interpolating observed station water level to f->time")
		station_obs = int2p_Wrap(station_obs_time, WaterLevel, f->time, 1)
	end if

	trackfile = idir+"fort.22"
	lines := asciiread(trackfile,-1,"string")
	delim = ","
	tracklon = -1 * tofloat(str_get_field(lines, 8, delim))/10.
	tracklat = tofloat(str_get_field(lines, 7, delim))/10.
	tt := str_get_field(lines, 3, delim)
	year   := tointeger(str_get_cols(tt, 1, 4))
	month  := tointeger(str_get_cols(tt, 5, 6))
	day    := tointeger(str_get_cols(tt, 7, 8))
	hour   := tointeger(str_get_cols(tt, 9,10))
	minute := hour
	minute = 0
	second := hour
	second = 0
	tracktime = ut_inv_calendar(year, month, day, hour, minute, second, station_time@units, 0)
	trackheading := tofloat(str_get_field(lines, 26, delim))
	trackI := sin(trackheading/180*3.141592)
	trackJ := cos(trackheading/180*3.141592)
	vmax   := tofloat(str_get_field(lines, 9, delim))
	rad    := tofloat(str_get_field(lines, 12, delim))

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
	sres@tiMainString           = modelstr + " run,  notide=" + notide
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
	if(.not.fileexists(control_timeseries_file).and.modelstr.ne."control")then
		print("control timeseries file doesn't exist yet. make it.")
	end if
	c := addfile(control_timeseries_file,"r")

	if(isfilepresent(timeseries_file))then
		g = addfile(timeseries_file,"w")
	else
		g = addfile(timeseries_file,"c")
	end if
	; If inundation_volume variable is missing, initialize it. Otherwise preserve it.
	if(.not.isfilevar(g,"inundation_volume"))then
		inundation_volume = new(ntime,double,-999.); need short number for titles (default is minus 1 zillion billion)
		inundation_volume@long_name = "inundation volume in surge zone"
		inundation_volume@units = "km~S~3~N~"
		inundation_volume@depth_threshold = thresh
		inundation_volume@depth_threshold_units = "m"
		inundation_volume!0 = "time"
		inundation_volume&time = zeta&time
		g->inundation_volume = inundation_volume
	end if
	inundation_volume = g->inundation_volume
	; If any of these fields don't exist, re-initialize them all. Otherwise preserve them.
	if(any(.not.isfilevar(g, (/"volume_in_ctrl","length_scale","inundation_true","average_depth","inundation_area"/) )))then
		volume_in_ctrl = new(dimsizes(inundation_volume),typeof(inundation_volume))
		copy_VarMeta(inundation_volume,volume_in_ctrl)
		length_scale = volume_in_ctrl
		copy_VarMeta(inundation_volume,length_scale)
		length_scale@long_name = "length_scale of surge zone"
		length_scale@units = "km"
		length_scale@left_percentile = left_percentile
		length_scale@right_percentile = right_percentile
		average_depth = length_scale
		copy_VarMeta(length_scale, average_depth)
		average_depth@long_name = "average depth in surge zone"
		average_depth@units = "m"
		inundation_area = length_scale
		copy_VarMeta(length_scale,inundation_area)
		inundation_area@long_name = "area of surge zone"
		inundation_area@units = "km~S~2~N~"
		inundation_true = new((/ntime,nnodes/),byte)
		inundation_true@long_name = "1b=inundated"
		inundation_true!0="time"
		inundation_true&time = zeta&time
		inundation_true!1="node"
		g->inundation_true = inundation_true
		g->length_scale = length_scale
		g->volume_in_ctrl=volume_in_ctrl
		g->average_depth=average_depth
		g->inundation_area=inundation_area
	end if
	inundation_true = g->inundation_true
	length_scale    = g->length_scale; yes..  it is important to have x=g->x after g->x=g for some reason
	volume_in_ctrl  = g->volume_in_ctrl ; yes..  it is important to have x=g->x after g->x=g (in loop above)
	average_depth   = g->average_depth
	inundation_area = g->inundation_area
	tmp := dimsizes(inundation_true)
	if(tmp(1).ne.nnodes)then
		printVarSummary(inundation_true)
		print(nnodes)
		print("do you need to delete "+timeseries_file+" and run again with stride="+tostring(stride)+"?")
		exit
	end if
	g->inundation_volume = inundation_volume
	g->inundation_true = inundation_true
	g->length_scale = length_scale
	g->volume_in_ctrl = volume_in_ctrl
	g->average_depth = average_depth

	; meta data for sanity check
	txres = True
	txres@txFontHeightF = 0.01
	txres@txJust  = "BottomLeft"

; uncommment to just plot the time with maximum bulge volume
; assumes time series is complete already

	itime = maxind(inundation_volume)
	if(ismissing(itime))then
		itime=235
	end if

	first_frame = True
	do itime=210,ntime-1,1
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
		dist := gc_latlon(res@sfYArray,res@sfXArray,conform(res@sfYArray,tracklat0,-1),conform(res@sfXArray,tracklon0,-1),2,-4) ; accurate calculation (great-circle distance)
		if(min(dist).gt.ring_km)then
			print("storm outside domain. skipping.")
			continue
		end if
		lat :=  transpose( (/ onedtond(tracklat0,dimsizes(res@sfYArray)), onedtond(trackJ0,dimsizes(res@sfYArray)), res@sfYArray /) )
		lon :=  transpose( (/ onedtond(tracklon0,dimsizes(res@sfXArray)), onedtond(trackI0,dimsizes(res@sfXArray)), res@sfXArray /) )
		LorR := gc_dangle(lat,lon)
		dist_right = dist * -sin(LorR/180.*3.141592)
		zeta1 := zeta(itime,:)

		; Dot nodes 
		ssres                  = True
		ssres@gsMarkerColor    = "pink"
		ssres@gsMarkerIndex    = 1
		ssres@gsMarkerSizeF    = 0.005
		ssres@gsMarkerOpacityF = 0.5

		; inundation is water height above MSL minus surface height above MSL (depth is negative for positive height above MSL)
		inundation = zeta1 + depth
		copy_VarMeta(zeta1, inundation)
		inundation@long_name = "water depth over land"
		; Isolate start dry land. Mask ocean, but not low-lying land nodes below mean sea level.
		; sfc_sub_state is missing or 1. 1 is land that starts dry but depth>0 (is below MSL). 
		inundation = mask(inundation, depth.le.0 .or. sfc_sub_state.eq.1, True)
		res@sfDataArray = inundation
		map := gsn_csm_contour_map(wks,inundation,res)

		; Tried to use gsn_polymarker procedure but dots would be overlaid by filled contours.
		volume = areaCell * inundation/1000. ; areaCell has already been multiplied by stride
		; added thresh threshold Feb 23, 2016. only count nodes where inundation exceeds this depth.
		; Set volumes to zero where inundation depth is less than threshold.
		; This affects length scale, average depth, total inundation volume, inundation area...
		printMinMax(inundation,False)
		volume = where(.not.ismissing(inundation).and.inundation.ge.thresh,volume,0.) 
		;tmp := maxind(volume)
		;print("max inundation node in domain: areaCell="+tostring(areaCell(tmp))+"sq km, inundation="+tostring(inundation(tmp))+"m, "+tostring(res@sfXArray(tmp))+"E "+tostring(res@sfYArray(tmp))+"N")
		if(sum(volume).eq.0)then
			print("no inundation above threshold. skipping time.")
			continue
		end if
		left_length_km  = get_length_scale(volume,dist_right, left_percentile/100.)
		right_length_km = get_length_scale(volume,dist_right, right_percentile/100.)
		g->length_scale(itime) = right_length_km - left_length_km
		; Draw LS contours (left and right sides)
		LSres = True
		LSres@gsnDraw = False
		LSres@gsnFrame = False
		LSres@cnLevels = (/ left_length_km, right_length_km /)
		LSres@cnLevelSelectionMode = "ExplicitLevels"
		LSres@cnExplicitLineLabelsOn = True
		LSres@cnLineLabelBackgroundColor = -1
		LSres@cnLineLabelStrings = (/ "Left: "+sprintf("%.0fkm",left_length_km), "Right: "+sprintf("%.0fkm",right_length_km) /)
		LSres@cnLineLabelInterval = 1
		LSres@sfFirstNodeIndex = res@sfFirstNodeIndex
		LSres@sfXArray = res@sfXArray
		LSres@sfYArray = res@sfYArray
		LSres@cnInfoLabelString = "length scale $CMN$ to $CMX$ km"
		;LSres@cnLevelSelectionMode = "AutomaticLevels" ; plot a bunch of contours
		LS := gsn_csm_contour(wks, dist_right, LSres)
		overlay(map, LS)
		; used to be .and.inundation.ge.0, but we don't want dry land nodes
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
			print("not drawing this frame")
			continue
		end if
		first_frame = False



		; tried to use gsnLeftString resource but it wouldn't update the resource on the map object after I created map.
		title := sprintf("~C~surge zone defined by %.0f",right_percentile-left_percentile)+"% of volume (" +sprintf("%.1f",left_percentile)+"% to the left and "+sprintf("%.1f",100.-right_percentile)+"% to the right) where depth >= "+thresh_string+"~C~surge zone volume " + sprintf(":%6.2f", inundation_volume(itime)) + inundation_volume@units + " / length:" + sprintf("%4.0fkm",right_length_km-left_length_km) + " average depth: " + sprintf("%.1fm",g->average_depth(itime)) + " / area: "+ sprintf("%.0f km~S~2~N~",g->inundation_area(itime)) + "~C~surge zone volume intersecting surge zone of control run (pink): " + sprintf("%6.2fkm~S~3~N~",volume_in_ctrl(itime))
		gsn_text_ndc(wks,title, 0.204, 0.6, txres)
		storm_track := gsn_add_polyline(wks,map,tracklon,tracklat,lres)

		
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

		storm_center_res@gsMarkerIndex = create_hurricane_symbol(wks,tracklat0,vmax0)
		storm_center := gsn_add_polymarker(wks,map,tracklon0,tracklat0,storm_center_res)
		vmax_res = True
		vmax_res@txFontHeightF = 0.02
		vmax_res@txFontOpacityF = 0.7
		storm_center_vmax := gsn_add_text(wks,map,sprintf("%.0fkt",vmax0),tracklon0,tracklat0,vmax_res)

		draw(map)
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


