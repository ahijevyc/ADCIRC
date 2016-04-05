load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"

begin	
	; forked from simple_plot.ncl Nov 13 2015

	; Run first with type="avg"

	type = "avg"
	;type = "stddev"
	;type = "zscore"
	if(type.eq."avg")then
		type_str = "Mean"
	end if
	if(type.eq."rmssdn")then
		type_str = "Root of mean square (for mean divide by n-1)"
	end if
	if(type.eq."zscore")then
		type_str = "Standard Deviation divided by Mean"
	end if
	if(type.eq."stddev")then
		type_str = "Standard Deviation"
	end if
	type_str = type_str + " of veer ensemble"
	idir = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/control/" ; "coldstart_extend" and ADCIRC control RUN
	workdir = "/glade/p/work/ahijevyc/ADCIRC/control/"
	notide = False
	; zoom level
	if(.not.isdefined("zoom"))then
		zoom = 1 
	end if

	res = True
	res = set_res_mp(res,"zoom"+sprintf("%.0f",zoom))

	print("opening "+idir+"maxele.63.nc")
	f = addfile(idir+"maxele.63.nc","r")

	; hack to plot standard deviation of max water height across control and veer runs.
	infile = workdir+"notideFalse_"+type+".maxele.63.nc"
	if (fileexists(infile)) then
		print("using old "+infile)
	else
		members = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/"+(/"control","veer*"/)+"/maxele.63.nc"
		; make average file.
		avg_file = workdir+"notideFalse_avg.maxele.63.nc"
		stddev_file = workdir+"notideFalse_stddev.maxele.63.nc"
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
	f = addfile(infile,"r")

	if(notide)then
		print("not setup for notide")
		exit
	end if

	k = ind(f->x .ge.res@mpMinLonF.and.f->x .le.res@mpMaxLonF.and.f->y .ge.res@mpMinLatF.and.f->y .le.res@mpMaxLatF)

	sm = ".temporarysmallgrid"
	system("rm -v "+sm+".nc") 
	g = addfile(sm+".nc","c")
	g->zeta_max = f->zeta_max(k)
	g->depth = f->depth(k)
	g->x = f->x(k)
	g->y = f->y(k)
	; get area asssociated with each node (file created by Michael Duda)
	a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/adcirc_Ike_tri_mesh.nc","r")
	g->areaCell = a->areaCell(k)
	delete(g)
	delete(k)
	delete(a)
	f = addfile(sm+".nc","r")
	wks = gsn_open_wks("png",workdir+type+"_notide"+notide+".zoom"+zoom)
	nnodes = dimsizes(f->zeta_max) ; number of nodes
	stride = tointeger(max( (/ 1., nnodes^0.4/100 /) ))
	zeta_max = f->zeta_max(::stride)
	depth  = f->depth(::stride)

	Re = 6371.; radius of Earth in km
	areaCell := f->areaCell(::stride) * Re^2.

	gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
	res@cnLevelSelectionMode     = "ManualLevels"
	res@cnMinLevelValF           =  0. 
	res@cnMaxLevelValF           =  5.
	res@cnLevelSpacingF          =  0.5
	if(type.eq."stddev")then
		res@cnMaxLevelValF           =  2.6
		res@cnLevelSpacingF          =  0.2
	end if
	if(type.eq."zscore")then
		res@cnMaxLevelValF           =  2.6
		res@cnLevelSpacingF          =  0.2
	end if
		

	res@sfFirstNodeIndex         = 1
	res@sfXArray                 = f->x(::stride)
	res@sfYArray                 = f->y(::stride)
	inundation                   = mask(zeta_max + depth, depth.le.0, True)
	res@sfDataArray              = inundation

	res@cnFillOn                 = True
	res@cnFillMode               = "RasterFill"
	res@cnLinesOn                = False
	res@lbTitleString            = "maximum inundation (meters)"
	res@lbTitleFontHeightF       = 0.018
	res@lbTitlePosition          = "Bottom"
	res@gsnLeftString            = type_str

	; Don't advance the frame.
	res@gsnFrame = False

	res@mpDataBaseVersion       = "HighRes"     ; "MediumRes" will run faster.
	res@mpLimitMode             = "LatLon"
	res@mpPerimOn               = False
	res@pmTickMarkDisplayMode   = "Always"    ; Turn on map tickmarks.
	lres                        = True
	lres@gsLineThicknessF       =  2.
	lres@gsLineLabelFontHeightF = 0.009

	map := gsn_csm_contour_map(wks,zeta_max,res)
	txres = True
	txres@txFontHeightF = 0.01
	txres@txJust        = "BottomLeft"
	gsn_text_ndc(wks, "domain "+tostring(zoom)+" every "+tostring(stride)+" nodes~C~"+systemfunc("date"),0.01,0.01,txres)
	; Draw a dot on each node.
	mkres                   = True
	mkres@gsMarkerIndex     = 1
	mkres@gsMarkerSizeF     = 0.0005
	mkres@gsMarkerOpacityF  = 0.007
	gsn_polymarker(wks,map,res@sfXArray,res@sfYArray,mkres)

	; draw tracks for all veers
	trackfiles = systemfunc("ls "+idir+"fort.22  /glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/*/fort.22 ")
	do iveer=0,dimsizes(trackfiles)-1  
		trackfile = trackfiles(iveer)
		modelstr = systemfunc("basename " + systemfunc("dirname "+trackfile))
		; NOS is not "tracked". It is forced by U,V, grids. Don't plot the "track" for NOS. THere is none.
		if(modelstr.eq."NOS_OWI")then ; fort.22 is quite different for the NOS run. it don't have lat/lon of track.
			continue
		end if
		if(fileexists(trackfile))then
			print("reading "+trackfile)
			lines := asciiread(trackfile,-1,"string")
			delim = ","
			tracklon := -1 * tofloat(str_get_field(lines, 8, delim))/10.
			tracklat := tofloat(str_get_field(lines, 7, delim))/10.
			tt     := str_get_field(lines, 3, delim)
			year   := tointeger(str_get_cols(tt, 1, 4))
			month  := tointeger(str_get_cols(tt, 5, 6))
			day    := tointeger(str_get_cols(tt, 7, 8))
			hour   := tointeger(str_get_cols(tt, 9,10))
			minute := hour
			minute = 0
			second := hour
			second = 0
			lres@gsLineLabelString = modelstr
			gsn_polyline(wks,map,tracklon,tracklat,lres)
		end if
        end do
	

	frame(wks)
end

