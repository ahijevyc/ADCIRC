load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/work/ahijevyc/ncl/derived_fields.ncl"
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/work/ahijevyc/ncl/CreateTracks.ncl"

;==========================================================================

; written by David Ahijevych
; MSLP contour and windbarbs

begin

	field = "speed_10m"
	; Plotting domain
	domain = "Irma"
    mesh = "nos"

	; Directory with esmf regrid files for this particular mesh 
	meshdir = "/glade/work/ahijevyc/ADCIRC/esmf_regrid."+mesh+"/"
	diri = "/glade/work/ahijevyc/ADCIRC/IRMA/control/"
	diri = "/glade/scratch/mpasrt/uni/2017090600/ecic/latlon_0.125deg_025km/"

	slpfile = diri+"fort.73.nc"

	; Open initialization file and read lat/lon/cell information.
	f73 = addfile(slpfile,"r")
	lon = f73->x
	time = f73->time
    f63 = addfile(diri+"fort.63.nc","r")
    copy_VarAtts(f63->time, time)
    ;print(cd_string(time, "%Y%N%D %H%M"))
    iTime = 119 ; good for control init 2017090718 
    iTime = 119-42 ; good for init 2017090600 valid 201709100600 fhr=102
    print(cd_string(time(iTime), "%Y%N%D %H%M"))
	nCells         = dimsizes(lon)
	print("done reading lat/lon info")

    f74 = addfile(diri+"fort.74.nc","r")
	ofile = field+"."+domain+".png"
	wks_type = "png"
	wks = gsn_open_wks(wks_type,ofile)

	;SET RESOURCES:
	res = True
	res@mpProjection        = "CylindricalEquidistant"
	res@mpDataBaseVersion   = "MediumRes" 
	res@mpLimitMode = "LatLon"
	res@mpMinLatF=  20.2
	res@mpMaxLatF=  28.2
	res@mpMinLonF= -87.
	res@mpMaxLonF= -74.9
	; set sfXArray and sfYarray (1-D lats and lons needed for plotting a mesh)
	res@sfXArray = f73->x
	res@sfYArray = f73->y
  
	sres = True
    sres@sfXArray = res@sfXArray
    sres@sfYArray = res@sfYArray

	; MSLP contour
    meters_of_water = f73->pressure
    air_pressure = meters_of_water * 9.81 * 1000 /100
    printMinMax(air_pressure,False)
 
	ustr = "windx"
	vstr = "windy"
	; Regrid u and v wind components to lat-lon with ESMF_regrid function.
	; Based on Bill Skamarock's scripts in /glade/p/mmm/skamaroc/Spring_exp/Test_forecasts/Test_ortho

	
	source_points_file = meshdir + "source_cells_"+domain+".nc"
	;---destination lat-lon mesh
	dlat = 0.25
	dlon = 0.25
	lat_north =  30.
	lat_south =  20.
	lon_west = -90.
	lon_east = -74.
    span_dateline = False

 	lonCell = res@sfXArray
 	latCell = res@sfYArray

	nlat = floattointeger((lat_north-lat_south)/dlat) + 1
	nlon = floattointeger((lon_east-lon_west)/dlon) + 1

	print(" nlat and nlon "+nlat+" "+nlon)

	rlatCell = new( (/nCells/), double )
	rlonCell = new( (/nCells/), double )

	; Find all the mesh points that fall within your box.
	; Save their lats and lons in rlatCell and rlonCell.
	; Use the premade file if it exists.
	if(isfilepresent(source_points_file)) then

		pf = addfile(source_points_file,"r")
		cell_idx = pf->cell_idx
		print(" finished reading "+source_points_file)
		icnt = pf->icnt
		print(" icnt = "+icnt)
		rlatCell(0:icnt-1) = latCell(cell_idx(0:icnt-1))
		rlonCell(0:icnt-1) = lonCell(cell_idx(0:icnt-1))
		dst_lat = pf->dst_lat 
		dst_lon = pf->dst_lon

	else
        print("run_esmf_regid: did not find src points file "+source_points_file)
        ; On Jul 18, 2017 ahijevych remade the wp domain. He needed to erase the src dst, etc. files
        ; and load module ncl/6.3.0 (not default 6.4.0)

		icnt=0
		cell_idx = new( (/nCells/), integer)
		dst_lat = new((/nlat,nlon/),float)
		dst_lon = new((/nlat,nlon/),float)

		do j=0,nlat-1
		do i=0,nlon-1
			dst_lat(j,i) = lat_south + j * dlat
			dst_lon(j,i) = lon_west + i * dlon
		end do
		end do
		lat1     = min(dst_lat) - 1. 
		lat2     = max(dst_lat) + 1.
		lon1     = min(dst_lon) - 1.
		lon2     = max(dst_lon) + 1.

		do i=0,nCells-1
            ; map to -180 - 180 unless dateline is spanned.
            ; If dateline is spanned keep lonCell in 0-360 range.
			if(.not.span_dateline.and.lonCell(i).gt.180.) then
			  lonCell(i)=lonCell(i)-360.
			end if

			if (latCell(i).ge.lat1) then
			if (latCell(i).le.lat2) then
			if (lonCell(i).ge.lon1) then
			if (lonCell(i).le.lon2) then

			  rlatCell(icnt) = latCell(i)
			  rlonCell(icnt) = lonCell(i)
			  cell_idx(icnt) = i
			  icnt = icnt+1

			end if
			end if
			end if
			end if

		end do

		pf = addfile(source_points_file,"c")
		print("creating "+source_points_file)
		pf->cell_idx = cell_idx
		pf->icnt = icnt
		pf->dst_lat = dst_lat
		pf->dst_lon = dst_lon
	end if
	print ("number of Cells in "+domain+" ::"+icnt)

	print(" lat min and max "+dst_lat(0,0)+" "+dst_lat(nlat-1,0))
	print(" lon min and max "+dst_lon(0,0)+" "+dst_lon(0,nlon-1))
	print ("number of Cells in "+domain+" ::"+icnt)

;==================================================================================

;---Set up regridding options
	Opt                   = True
;---"bilinear" is the default. "patch" and "conserve" are other options.
	Opt@InterpMethod      = "bilinear" 

	Opt@SrcGridLat        = rlatCell(0:icnt-1) 
	Opt@SrcGridLon        = rlonCell(0:icnt-1)
	Opt@SrcRegional       = True   
	;Opt@SrcMask2D         = where(.not.ismissing(var),1,0) ; Necessary if has missing values.

	Opt@DstGridLat        = dst_lat
	Opt@DstGridLon        = dst_lon
	Opt@DstRegional       = True 

	Opt@ForceOverwrite    = False
	Opt@PrintTimings      = False
	Opt@Debug             = False
	Opt@NoPETLog          = True
	Opt@RemovePETLog      = True

	;Opt@SrcTriangularMesh = True

	Opt@WgtFileName       = meshdir + "esmf_wgt_"+domain+".nc"
	if(isfilepresent(Opt@WgtFileName))then
		Opt@SkipWgtGen = True
	end if
	Opt@DstFileName       = meshdir + "esmf_dst_"+domain+".nc"
	if(isfilepresent(Opt@DstFileName))then
		Opt@SkipDstGrid = True
	end if
	Opt@SrcFileName       = meshdir + "esmf_src_"+domain+".nc"
	if(isfilepresent(Opt@SrcFileName))then
		Opt@SkipSrcGrid = True
	end if

	; U 
	u := f74->$ustr$(iTime,:)
    printMinMax(f74->$ustr$,False)	
    printMinMax(f74->$ustr$(0,:),False)	
    printMinMax(f74->$ustr$(iTime,:),False)	
    printMinMax(u,False)	
	; Extract cells within domain limits.
	u := u(cell_idx(0:icnt-1))
	u := ESMF_regrid(u,Opt)
	u@lat2d = dst_lat
	u@lon2d = dst_lon

    printMinMax(u,False)	
	; V
	v := f74->$vstr$(iTime,:)
	; Extract cells within domain limits.
	v := v(cell_idx(0:icnt-1))
	v := ESMF_regrid(v,Opt)
	v@lat2d = dst_lat
	v@lon2d = dst_lon
	
	print("done regridding u & v wind")

    fld := get_speed(f74,"10m")
    printVarSummary(fld)
    printMinMax(fld,False)
    res = get_field_res(wks, "speed_10m", fld)
    res@cnMaxLevelValF = 100.

    ; wind speed colors
    plot = gsn_csm_contour_map(wks, fld(iTime,:),res) 

	; Cosmetic changes for wind barbs
	vres = True
	vres@gsnDraw = False
	vres@gsnFrame = False
	vres@vcRefLengthF    = 0.024
	vres@vcGlyphStyle = "WindBarb"
	vres@vcPositionMode = "ArrowHead"
	vres@vcMinDistanceF = 0.030
	vres@vcRefAnnoOn = False
	vres@vcWindBarbLineThicknessF = 1.6
	vres@vcWindBarbScaleFactorF = 1.94384
	plot_ov = gsn_csm_vector(wks,u,v,vres)
	overlay(plot,plot_ov)

	; MSLP contours
    sres = get_res_cn("", "mslp", air_pressure)
    ;plot_ov = gsn_csm_contour(wks,air_pressure(iTime,:),sres)
    ;overlay(plot, plot_ov)

    if(False)then
        trackfile = diri + "fort.22"
        adeck := read_atcf(trackfile)
        tklon = adeck@lon
        tklat = adeck@lat
        adeck_valid = adeck@valid
        adeck_valid@units = adeck@timeunits
        tracktime = cd_convert(adeck_valid, f63->time@units)
        vmax = adeck@vmax
        tkres = True
        tkres@gsMarkerSizeF=0.02
        tkres@gsMarkerIndex = create_tropical_symbol(wks,tklat(iTime),vmax(iTime))
        tkres@gsMarkerColor = "Black"

        tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
    end if

	draw(plot)
	frame(wks)
	print("finished "+ofile)

end

