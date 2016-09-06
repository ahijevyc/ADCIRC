load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"

; copied from simple_plot.ncl on Jan 25, 2016
; started removing observational stuff and removed ability to subtract no-storm, just tides run.

begin

	if(.not.isvar("modelstr"))then
		modelstr = "control"
	end if
	if(.not.isvar("stormname"))then
		stormname = "IKE"
	end if
	basedir = "/glade/scratch/fossell/ADCIRC/"
	basedir = "/glade/scratch/ahijevyc/adcirc/"
	modeldir = basedir + stormname+"/"+modelstr+"/" 
	obsdir   = basedir + stormname+"/control/" 
	if(stormname.eq."IKE")then
		modeldir = basedir + "ike/nos_grid/v51_additive_perts/"+modelstr+"/" 
		obsdir   = basedir + "ike/nos_grid/v51_additive_perts/control/" 
	end if
	workdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
	; zoom level
	if(.not.isdefined("zoom")) then
		zoom = 1
	end if

	res = True
	res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

	print("opening "+modeldir+"maxele.63.nc")
	f = addfile(modeldir+"maxele.63.nc","r")

	k = ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)

	obs_file   = "/tmp/"+stormname+  ".control"+".zoom"+zoom+".nc" ; temporary mesh zoomed to lat/lon bounds
	model_file = "/tmp/"+stormname+"."+modelstr+".zoom"+zoom+".nc" ; used later in script
	files = (/ obs_file, model_file /)
	full_files = (/ obsdir, modeldir /) + "maxele.63.nc"

	a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/adcirc_Ike_tri_mesh.nc","r")
	; Read file that lists nodes where surface submergence state is 1
	sfc_sub_state_file = "/glade/p/work/ahijevyc/ADCIRC/surface_submergence_state_14040.txt"
	lines = asciiread(sfc_sub_state_file, -1, "integer")
	inodes = lines(::2) ; asciiread reads 2 columns text into 1-D array; extract 1st column by taking every other one.
	sfc_sub_state = new(dimsizes(f->zeta_max), "integer")
	; The sfc_sub_state_file lists node indices where indices are 1-based.  But ncl is zero-based.  So subtract one from the node indices.
	sfc_sub_state(inodes-1) = 1
	sfc_sub_state := sfc_sub_state(k)

	; loop through obs (i=0) and model (i=1)
	do i=0,1
		system("rm -v "+files(i)) 
		g = addfile(files(i),"c")
		f = addfile(full_files(i),"r")
		g->zeta_max = f->zeta_max(k)
		g->depth = f->depth(k)
		g->x = f->x(k)
		g->y = f->y(k)
		; get area asssociated with each node (file created by Michael Duda)
		g->areaCell = a->areaCell(k)

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
		g->inundation = inundation
	end do

	outfile = workdir+modelstr+".perfectmodel.zoom"+zoom
	if(isfilepresent(outfile+".nc"))then
		system("rm -v "+outfile+".nc")
	end if
	out2 = addfile(outfile+".nc","c")
	
	wks = gsn_open_wks("png",outfile)
	trackfile = modeldir+"fort.22"
	; fort.22 is quite different for the NOS run. it don't have lat/lon of track.
	if(fileexists(trackfile).and.modelstr.ne."NOS_OWI")then
		print("reading "+trackfile)
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
	end if



	f = addfile(model_file,"r")
	nnodes = dimsizes(f->zeta_max) ; number of nodes
	inundation = f->inundation
	zeta_max = f->zeta_max
	depth = f->depth

	Re = 6371.; radius of Earth in km
	areaCell := f->areaCell * Re^2.

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

	; Don't advance the frame.
	res@gsnFrame = False

	res@pmTickMarkDisplayMode = "Always"    ; Turn on map tickmarks.
	res@cnConstFLabelOn       = False ; don't say "CONSTANT FIELD - VALUE IS 0"
	lres                      = True
	lres@gsLineThicknessF     =  4.


	map := gsn_csm_contour_map(wks,inundation,res) ; attributes matter, but 2nd argument data values have no influence; had to define res@sfDataArray.
	getvalues map@contour ; used in histogram
		"cnLevels" : cnLevels
		"cnFillColors" : cnFillColors
	end getvalues

	txres = True
	txres@txFontHeightF = 0.015
	txres@txJust        = "BottomLeft"
	gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)
	; Draw a dot on each node.
	noderes                   = True
	noderes@gsMarkerIndex     = 1
	noderes@gsMarkerSizeF     = 0.001
	noderes@gsMarkerOpacityF  = 0.007
	if(zoom.eq.4) then
		noderes@gsMarkerSizeF     = 0.008
		noderes@gsMarkerOpacityF  = 0.85
		noderes@txFontHeightF   = 0.006
		noderes@txJust = "CenterRight"
		print("labeling nodes")
		gsn_text(wks,map,sprintf("d=%.1f ",depth)+"~C~"+sprintf("z=%.1f ",zeta_max),res@sfXArray,res@sfYArray,noderes)
		noderes@gsMarkerColor     = "blue" 
		gsn_polymarker(wks,map,res@sfXArray,res@sfYArray,noderes)
		reddot = noderes
		reddot@gsMarkerColor     = "dark green"
		reddot@gsMarkerSizeF     = 0.02
		tmp := ind(depth.le.0)
		gsn_polymarker(wks,map,res@sfXArray(tmp),res@sfYArray(tmp),reddot)
		tmp := ind(sfc_sub_state.eq.1)
		reddot@gsMarkerColor     = "red"
		reddot@gsMarkerSizeF     = 0.015
		if(.not.all(ismissing(tmp)))then
			gsn_polymarker(wks,map,res@sfXArray(tmp),res@sfYArray(tmp),reddot)
		end if
	end if
	;gsn_polymarker(wks,map,res@sfXArray,res@sfYArray,noderes)
	print("dotted nodes")

	; Get "observations" from control run.
	print(obs_file)
	print(model_file)
	g = addfile(obs_file,"r")
	obs = g->inundation
	g = addfile(model_file,"r")
	model=g->inundation
	obsres = True
	obsres@gsMarkerIndex = 4
	obsres@gsMarkerColor = "dark green"
	obsres@gsMarkerSizeF = 0.004
	obsres@gsMarkerThicknessF = 2.
	if(num(.not.ismissing(obs)).lt.1000.and.num(.not.ismissing(obs)).gt.0)then
		gsn_polymarker(wks,map,g->x,g->y,obsres)
		obsres@txFontColor = obsres@gsMarkerColor
		obsres@txJust = "CenterLeft"
		obsres@txFontHeightF = 0.008
		; draw dot (NhlTmarkerIndex=1) on node
		noderes@gsMarkerIndex = 1
		noderes@gsMarkerColor = "black"
		gsn_polymarker(wks,map,g->x,g->y,noderes)
		; Mark observation
		gsn_text(wks,map,sprintf("%6.2f~C~",obs)+sprintf("%6.2f",model),g->x,g->y,obsres)
	end if
	gsn_polyline(wks,map,tracklon,tracklat,lres)


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
	; I thought I understood the output of regline_stats but I don't.
	rc = regline(obs, model)
	print(rc)
	if(rc@nptxy.lt.3)then
		frame(wks)
		print("finished "+outfile)
		exit
	end if
        r := sum((obs-rc@xave)*(model-rc@yave))/stddev(obs)/stddev(model)/(rc@nptxy-1)
	r2 := r^2.
	rc_tmp := regline_stats(obs,model)
	if(abs(r2-rc_tmp@r2).gt.0001)then
		print(rc_tmp)
		print(r2)
		exit
	end if
	rmse = sqrt(avg((obs-model)^2))
	si = stddev(obs-model)/avg(obs)
	data = new ( (/3, dimsizes(obs)/), typeof(model))
	data(0,:) = model
	data(1,:) = rc*obs + rc@yintercept
	data(2,:) = (/ obs /); 1:1 line (obs vs obs)
	out2->obs = obs
	out2->model = model
	out2->rc = rc
	out2->rc_tmp = rc_tmp

	xyres                 = True                   ; plot mods desired
	; this controls the size and location of the first plot
	xyres@vpXF            = 0.75
	xyres@vpWidthF        = 0.20	    
	xyres@vpYF            = 0.96
	xyres@vpHeightF       = 0.20 

	xyres@gsnMaximize         = False                  ; maximize plot in frame
	xyres@xyMarkLineModes     = (/"Markers","Lines","Lines"/)  ; choose which have markers
	xyres@xyMarker            = obsres@gsMarkerIndex               ; choose type of marker 
	xyres@xyMarkerColor       = "dark green"                ; Marker color
	xyres@xyMarkerSizeF       = obsres@gsMarkerSizeF         ; Marker size (default 0.01)
	xyres@xyMarkerThicknesses   = (/obsres@gsMarkerThicknessF,1,1/) 
	xyres@xyDashPatterns      = (/"Solid","Solid","Solid"/)                
	xyres@xyLineThicknesses   = (/1,1,2/) 
	xyres@xyLineColors        = (/xyres@xyMarkerColor,xyres@xyMarkerColor,"black"/)
	xyres@xyLabelMode         = "Custom"
	xyres@gsnShape            = True
	xyres@trYMinF             = 0.
	xyres@trXMinF             = 0.

	xyres@tiMainString        = "n="+sprintf("%.0f",rc@nptxy)+", r~S~2~N~="+sprintf("%4.2f",r2)+", multiplic. bias="+sprintf("%4.2f",rc@yave/rc@xave)+"~C~scatter index="+sprintf("%4.2f",si) + ", RMSE="+sprintf("%4.2fm",rmse)
	xyres@tiYAxisString       = modelstr + "~C~(m inundation over land)"
	xyres@tiXAxisString       = obs_file
	plot  = gsn_csm_xy (wks,obs,data,xyres)        ; create plot

	; 2nd page - full page scatterplot
	xyres@gsnMaximize          = True               ; maximize plot in frame
	xyres@pmLegendDisplayMode  = "Always"
	xyres@pmLegendSide         = "Bottom"
	xyres@xyExplicitLegendLabels = (/"(obs,model)","best-fit","1:1"/)
	xyres@xyExplicitLabels     = xyres@xyExplicitLegendLabels
	plot  = gsn_csm_xy (wks,obs,data,xyres)        ; create plot

	if(False)then
		; IKE landfall coordinates and heading in control run.
		clat = 29.3
		clon = -94.7
		trackJ0 =  30.81772
		trackI0 =  -95.39713
		dist := gc_latlon(res@sfYArray,res@sfXArray,onedtond(clat,dimsizes(res@sfYArray)),onedtond(clon,dimsizes(res@sfXArray)),2,-4)
		lat :=  transpose( (/ onedtond(clat,dimsizes(res@sfYArray)), onedtond(trackJ0,dimsizes(res@sfYArray)), res@sfYArray /) )
		lon :=  transpose( (/ onedtond(clon,dimsizes(res@sfXArray)), onedtond(trackI0,dimsizes(res@sfXArray)), res@sfXArray /) )
		LorR := gc_dangle(lat,lon)
		dist_right = dist * -sin(LorR/180.*3.141592)

		; Only count nodes within ctrl. 
		volumes = areaCell/1000.*inundation
		icontrol = ind(volumes.ge.0.and.dist_right.ge.62.and.dist_right.lt.285)

		title = "inundation swath volume in domain = "+sprintf("%.1f", sum(volumes))+" km~S~3~N~~C~"+\
			"in control inundation swath (pink) = "+sprintf("%.1f", sum(volumes(icontrol))) + " km~S~3~N~"
		map := gsn_csm_contour_map(wks,inundation,res)

		; Dot nodes 
		ssres                  = True
		ssres@gsMarkerColor    = "pink"
		ssres@gsMarkerIndex    = 1
		ssres@gsMarkerSizeF    = 0.005
		ssres@gsMarkerOpacityF = 0.05
		gsn_polymarker(wks,map,res@sfXArray(icontrol),res@sfYArray(icontrol),ssres)

		if(isdefined("tracklon"))then		
			gsn_polyline(wks,map,tracklon,tracklat,lres)
		end if
		gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)
		txres@txJust        = "TopLeft"
		gsn_text_ndc(wks, title,0.01,0.99,txres)
		frame(wks)
	end if

	print("finished "+outfile)
	
end

