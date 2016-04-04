load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_length_scale.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"

begin

	if(.not.isvar("modelstr"))then
		modelstr = "control"
	end if
	stormname = "CHARLEY"
	modeldir = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/"+modelstr+"/" 
	modeldir = "/glade/scratch/fossell/ADCIRC/"+stormname+"/"+modelstr+"/" 
	; modelstr has to be "coldstart_extend" one time - you will get an error but dont worry
	if(modelstr.eq."NOS")then
		modeldir = "/glade/scratch/fossell/ADCIRC/NOS/ikr09/NOS_OWI/" ; NOS run
	end if
	workdir = "/glade/p/work/ahijevyc/ADCIRC/"+stormname+"/"+modelstr+"/"
	; zoom level
	if(.not.isdefined("zoom")) then
		zoom = 1
	end if

	res                          = True
	res = set_res_mp(res, stormname+"_zoom"+sprintf("%.0f",zoom))

	print("opening "+modeldir+"maxele.63.nc")
	f = addfile(modeldir+"maxele.63.nc","r")

	k = ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)
	sm = "."+modelstr+".zoom"+zoom ; temporary small grid
	system("rm -v "+sm+".nc") 
	g = addfile(sm+".nc","c")
	g->zeta_max = f->zeta_max(k)
	g->depth = f->depth(k)
	g->x = f->x(k)
	g->y = f->y(k)
	; get area asssociated with each node (file created by Michael Duda)
	a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/adcirc_Ike_tri_mesh.nc","r")
	g->areaCell = a->areaCell(k)

	; Read file that lists nodes where surface submergence state is 1
	sfc_sub_state_file = "/glade/p/work/ahijevyc/ADCIRC/surface_submergence_state_14040.txt"
	lines = asciiread(sfc_sub_state_file, -1, "integer")
	inodes = lines(::2) ; asciiread reads 2 columns text into 1-D array; extract 1st column by taking every other one.
	sfc_sub_state = new(dimsizes(f->zeta_max), "integer")
	; The sfc_sub_state_file lists node indices where indices are 1-based.  But ncl is zero-based.  So subtract one from the node indices.
	sfc_sub_state(inodes-1) = 1
	g->sfc_sub_state = sfc_sub_state(k)

	; Max inundation. You can calculate volume but it doesn't make sense. This is a max over time at each point. 
	; The inundation is never actually this much at any time.  The max water height is spread over time as it washes over the land.
	; That's why the number here is so much larger than the number in the instantaneous bulge_timeseries. 
	inundation = g->zeta_max + g->depth
	; Set missing values to zero. Don't use num() to count non-missing values (zero is not missing but is not True either).
	if(any(ismissing(g->zeta_max)))then
		inundation(ind(ismissing(g->zeta_max))) = 0.
	end if
	; Only retain land values and low-lying land nodes below MSL (sfc_sub_state=1, or "startDry" nodes). 
	inundation = mask(inundation, (g->depth).le.0 .or. (g->sfc_sub_state.eq.1), True)
	inundation@long_name = "maximum inundation (all times)"
	inundation@units     = "m"
	g->inundation = inundation

	; Annotate surge station observations from Hal Needham and SURGEDAT project.
	; csv file is columns K, V, and W from ./observations/Ike_2008.xlsx (copied from pecan:/mmmtmp/ahijevyc Jan 2016) 
	obs_file = "./observations/Ike_2008_surge_station_obs.csv"
	obs_file = "./"+stormname+"/observations/"+stormname+"_SURGEDAT.csv"
	; ike_SSS_high_water.csv created by get_USGS_high_water.csh from pubs.usgs.gov/of/2008/1365/downloads
	;obs_file = "./"+stormname+"/observations/ike_SSS_high_water.csv"
	outfile = workdir+modelstr+".zoom"+zoom
	if(isStrSubset(obs_file,"USGS"))then
		outfile = workdir+modelstr+".USGS.zoom"+zoom
	end if
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



	f = addfile(sm+".nc","r")
	nnodes = dimsizes(f->zeta_max) ; number of nodes
	inundation = f->inundation
	zeta_max = f->zeta_max
	depth = f->depth
	sfc_sub_state := f->sfc_sub_state

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
	res@sfDataArray              = zeta_max; inundation


	res@cnFillOn                 = True
	res@cnFillMode               = "RasterFill"
	res@cnLineLabelsOn           = True
	res@cnLineLabelPlacementMode = "Constant"
	res@lbLabelAutoStride        = True
	res@lbTitleString            = "maximum water height above geoid (m)" ; "maximum inundation (meters)"
	res@lbTitleFontHeightF       = 0.018
	res@lbTitlePosition          = "Bottom"

	res@gsnCenterString          = modelstr
	res@gsnCenterStringOrthogonalPosF = 0.1
	res@gsnRightString           = ""

	; Don't advance the frame.
	res@gsnFrame = False

	res@mpDataBaseVersion     = "HighRes"     ; "MediumRes" will run faster.
	res@mpLimitMode           = "LatLon"
	res@mpPerimOn             = False
	res@pmTickMarkDisplayMode = "Always"    ; Turn on map tickmarks.
	res@cnConstFLabelOn       = False ; don't say "CONSTANT FIELD - VALUE IS 0"
	lres                      = True
	lres@gsLineThicknessF     =  4.


	map := gsn_csm_contour_map(wks,zeta_max,res); inundation,res) ; attributes matter, but 2nd argument data values have no influence; had to define res@sfDataArray.
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
		gsn_text(wks,map,sprintf("%5.1fm",depth)+"~C~"+sprintf("%5.1fm",zeta_max),res@sfXArray,res@sfYArray,noderes)
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

	print("reading "+obs_file)
	lines := asciiread(obs_file, -1, "string")
	strs = str_split_csv(lines, ",", 0)
	if(isStrSubset(obs_file,"USGS"))then
		stormtide_m = tofloat(strs(:,0))
		x = tofloat(strs(:,2))
		y = tofloat(strs(:,1))
		siteid = strs(:,3)
		confidence = x
		confidence = 3
	else
		skip = 1
		if(stormname.eq."CHARLEY")then
			skip=2
		end if
		stormtide_m = tofloat(strs(skip:,10))
		x = tofloat(strs(skip:,22))
		y = tofloat(strs(skip:,21))
		siteid = strs(skip:,17)
		confidence = tofloat(strs(skip:,24))
	end if
	print(confidence)
	obsres = True
	obsres@gsMarkerIndex = 4
	obsres@gsMarkerColor = "dark green"
	obsres@gsMarkerSizeF = 0.004
	obsres@gsMarkerThicknessF = 2.
	obsres@txFontColor = obsres@gsMarkerColor
	obsres@txJust = "CenterLeft"
	obsres@txFontHeightF = 0.012
	if(isdefined("tracklon"))then ; not applicable for NOS_OWI (doesn't use official IKE track)
		gsn_polyline(wks,map,tracklon,tracklat,lres)
	end if
	
	dist_errs = new(dimsizes(lines),"double")
	obs       = new(dimsizes(lines),"double")
	model     = new(dimsizes(lines),"double")
	; for each surge station observation
	do n = 0, dimsizes(x)-1
		if(ismissing(x(n)).or.ismissing(y(n)).or.ismissing(stormtide_m(n)).or.x(n).lt.res@mpMinLonF.or.x(n).gt.res@mpMaxLonF.or.y(n).lt.res@mpMinLatF.or.y(n).gt.res@mpMaxLatF)then
			; skip if observation is out of bounds
			continue
		end if
		; skip if confidence is less than 3
		if(.not.ismissing(confidence(n)))then
			if(confidence(n).lt.3)then
				print("confidence="+sprintf("%.0f",confidence(n))+sprintf("%8.2fE",x(n))+sprintf("%6.2fN",y(n))+" n="+sprintf("%4.0f",n)+" obs="+sprintf("%4.1fm",stormtide_m(n))+" ignoring ob")
				continue
			end if
		end if
		obs(n) = stormtide_m(n)
		; Find closest node to surge station
		;dist = gc_latlon(res@sfYArray,res@sfXArray,onedtond(y(n),dimsizes(res@sfYArray)),onedtond(x(n),dimsizes(res@sfXArray)),2,-4)
		dist = gc_latlon(res@sfYArray,res@sfXArray,conform(res@sfYArray,y(n),-1),conform(res@sfXArray,x(n),-1),2,-4)
		i = minind(dist)
		if(dist(i).gt.0.5)then
			print(sprintf("%7.2fE",x(n))+sprintf("%6.2fN",y(n))+sprintf("%4.0fm",1000*dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i)) + " n="+sprintf("%4.0f",n)+" obs="+sprintf("%5.1fm",obs(n))+" model="+sprintf("%4.1fm",model(n))+" closest node too far")
			continue
		end if
		dist_errs(n) = dist(i)
		model(n) = zeta_max(i)
		; if zeta_max is missing don't ignore the point--assign sfc elevation. treat it as zero inundation.
		; This is a problem for points along small rivers not resolved in ADCIRC mesh.
		; They have USGS obs of water but NOS mesh land is high and dry.
		; WARNING there are nodes with missing zeta_max and positive depth, like 401-ILA-03-060
		; Allow model(n) to be missing if this is the case.
		if(ismissing(zeta_max(i)).and.depth(i).le.0)then
			model(n) = -depth(i)
		end if
		print(siteid(n)+" "+tostring(obs(n))+" "+tostring(x(n))+" "+tostring(y(n))+" model:"+tostring(model(n)))
		if(ismissing(zeta_max(i)).and.depth(i).gt.0)then
			print(sprintf("%8.3fE",x(n))+sprintf("%7.3fN",y(n))+sprintf("%4.0fkm",dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i)))
			print(sprintf("%9.4fE",res@sfXArray(i))+sprintf("%8.4fN",res@sfYArray(i))+sprintf("%4.0fkm",dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i)))
			print("n="+sprintf("%4.0f",n)+" obs="+sprintf("%4.1fm",obs(n))+" model="+sprintf("%4.1fm",model(n))+" depth="+sprintf("%6.3fm",depth(i)))
		end if
		if(.not.ismissing(model(n)).and.abs(model(n)-obs(n)).gt.5)then
			print(sprintf("%7.2fE",x(n))+sprintf("%6.2fN",y(n))+sprintf("%4.0fm",1000.*dist(i))+" zeta_max="+sprintf("%6.2fm",zeta_max(i))+" depth="+sprintf("%6.2fm",depth(i)))
			print("n="+sprintf("%4.0f",n)+" obs="+sprintf("%5.2fm",obs(n))+" model="+sprintf("%5.2fm",model(n))+" conf="+sprintf("%.0f",confidence(n)))
		end if
		; draw dot (NhlTmarkerIndex=1) on node
		noderes@gsMarkerIndex = 1
		noderes@gsMarkerColor = "black"
		gsn_polymarker(wks,map,res@sfXArray(i),res@sfYArray(i),noderes)
		; Mark observation
		gsn_polymarker(wks,map,x(n),y(n),obsres)
		if(dimsizes(x).lt.50)then
			gsn_text(wks,map," "+sprintf("%5.2f",obs(n)),x(n),y(n),obsres)
		end if
	end do
	print("maximum distance from observation: "+sprintf("%3.1fkm",max(dist_errs)))

	printMinMax(obs,False)
	printVarSummary(model)
	printMinMax(model,False)
	if(num(.not.ismissing(obs)).ne.num(.not.ismissing(model)))then
		print("obs != model points")
		print(num(.not.ismissing(obs)))
		print(num(.not.ismissing(model)))
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
	xyres@xyDashPatterns      = (/"Solid","Solid","Solid"/)                
	xyres@xyLineThicknesses   = (/1,1,2/) 
	xyres@xyMarkerThicknesses   = (/obsres@gsMarkerThicknessF,1,1/) 
	xyres@xyLineColors        = (/xyres@xyMarkerColor,xyres@xyMarkerColor,"black"/)
	xyres@gsnShape            = True
	xyres@trYMinF             = 0.
	xyres@trXMinF             = 0.

	xyres@tiMainString        = "n="+sprintf("%.0f",rc@nptxy)+", r~S~2~N~="+sprintf("%4.2f",r2)+", multiplic. bias="+sprintf("%4.2f",rc@yave/rc@xave)+"~C~scatter index="+sprintf("%4.2f",si) + ", RMSE="+sprintf("%4.2fm",rmse)
	xyres@tiYAxisString       = modelstr + "~C~" + zeta_max@long_name + "~C~(meters)"
	xyres@tiXAxisString       = obs_file + "~C~(meters)"
	plot  = gsn_csm_xy (wks,obs,data,xyres)        ; create plot

	; 2nd page - full page scatterplot
	xyres@gsnMaximize          = True               ; maximize plot in frame
	xyres@pmLegendDisplayMode  = "Always"
	xyres@pmLegendSide         = "Bottom"
	xyres@xyExplicitLegendLabels = (/"(obs,model)","best-fit","1:1"/)
	xyres@xyExplicitLabels     = xyres@xyExplicitLegendLabels
	plot  = gsn_csm_xy (wks,obs,data,xyres)        ; create plot

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
	in_control_zone = 0
	if(.not.any(ismissing(icontrol)))then
		printVarSummary(in_control_zone)
		print(sum(volumes(icontrol)))
		in_control_zone := sum(volumes(icontrol))
	end if

	res@sfDataArray      = inundation
	title = "inundation swath volume in domain = "+sprintf("%.1f", sum(volumes))+" km~S~3~N~~C~"+\
		"in control inundation swath (pink) = "+sprintf("%.1f", in_control_zone) + " km~S~3~N~"
	map := gsn_csm_contour_map(wks,inundation,res)
	if(zoom.ge.3) then
		tmp := ind(inundation.ge.0.5)
		noderes@gsMarkerIndex     = 1
		print("labeling nodes")
		noderes@txFontHeightF = 0.005
		noderes@txJust = "CenterCenter"
		gsn_text(wks,map,sprintf("%3.1f",inundation(tmp)),res@sfXArray(tmp),res@sfYArray(tmp),noderes)
		gsn_polymarker(wks,map,res@sfXArray,res@sfYArray,noderes)
		print("dotted nodes")
	end if

	; Dot nodes 
	ssres                  = True
	ssres@gsMarkerColor    = "pink"
	ssres@gsMarkerIndex    = 1
	ssres@gsMarkerSizeF    = 0.005
	ssres@gsMarkerOpacityF = 0.05
	if(.not.any(ismissing(icontrol)))then
		gsn_polymarker(wks,map,res@sfXArray(icontrol),res@sfYArray(icontrol),ssres)
	end if

	; define array of volume fraction thresholds (0-1) to plot
	;fracts = (/ 0.9, 0.95, 0.99 /)
	;do ifract=0,dimsizes(fracts)-1
	;	fract = fracts(ifract)
	;	length_scale_km = get_length_scale(volumes,dist,fract)
	;	ring_res@gsLineLabelString = sprintf("%2.0f",fract*100)+"% "+sprintf("%4.0fkm", length_scale_km)
	;	nggcog(clat,clon,tofloat(length_scale_km)/Re*180./3.141592,rglat,rglon)
	;	gsn_polyline(wks, map, rglon, rglat, ring_res)
	;end do

	if(isdefined("tracklon"))then		
		gsn_polyline(wks,map,tracklon,tracklat,lres)
	end if
	gsn_text_ndc(wks, "domain "+tostring(zoom)+"~C~"+systemfunc("date"),0.01,0.01,txres)
	txres@txJust        = "TopLeft"
	gsn_text_ndc(wks, title,0.01,0.99,txres)
	frame(wks)

	hres                          = True
	hres@gsnHistogramBinIntervals = cnLevels
	hres@gsnHistogramMinMaxBinsOn = True
	hres@tiMainString             = res@gsnCenterString
	hres@gsFillColor              = cnFillColors
	plot := gsn_histogram(wks,inundation,hres)

	print("finished "+outfile)
	
end

