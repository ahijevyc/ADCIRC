    ; Define static attributes of the NOS mesh.
    ; hgt_MHHW
    ; areaCell
    ; sfc_sub_state


    ; Get node height relative to MHHW mark (hgt_MHHW)
    ; David Ahijevych created this file with vdatum June 2017.
    MHHW_file= "/glade/work/ahijevyc/ADCIRC/lonlatLMSL.MHHW.nc"
    MHHW_fh = addfile(MHHW_file, "r")
    ; Create a new variable to hold node height relative to mean higher high water.
    hgt_MHHW = MHHW_fh->mhhw
    hgt_MHHW@source = MHHW_file 
    delete(MHHW_fh)

    ; Get area asssociated with each node (file created by Michael Duda)
    areaCell_source = "/glade/work/ahijevyc/ADCIRC/duda/NOS_cells.nc"
    area_fh = addfile(areaCell_source, "r")
    Re = 6371.; radius of Earth in km
    areaCell = area_fh->areaCell
    areaCell = areaCell * Re^2.
    areaCell@long_name = "area of cell"
    areaCell@earth_radius = Re
    areaCell@units = "km^2"
    areaCell@source = areaCell_source
    delete(area_fh)


    ; Put start-dry NOS mesh nodes in variable sfc_sub_state

    ; Read file that lists nodes where surface submergence state is 1, or "start dry nodes". 
    ; They are actually contained in the fort.13 file, but that file has other attributes,
    ; so it's hard to parse.  So Kate pulled that chunk of data out to this text file.  
    ; The file lists the node number, which must be cross referenced with index of lat/lon vars or fort.14 file. 
    sfc_sub_state_file = "/glade/work/ahijevyc/ADCIRC/surface_submergence_state_14040.txt"
    lines = asciiread(sfc_sub_state_file, -1, "integer")
    inodes = lines(::2) ; asciiread reads 2 columns text into 1-D array; extract 1st column by taking every other one.
    sfc_sub_state = new(dimsizes(areaCell), "integer")
    ; The sfc_sub_state_file lists node indices where indices are 1-based.  But ncl is zero-based.  So subtract one from the node indices.
    sfc_sub_state(inodes-1) = 1
    sfc_sub_state@long_name = "1 is start-dry node. Converted from 1-based to zero-based node indices."
    sfc_sub_state@source = sfc_sub_state_file

