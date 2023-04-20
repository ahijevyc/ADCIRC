import pdb
import requests
import lxml.html as lh
import pandas as pd
# NOAA station data come from tidesandcurrents.noaa.gov
def turl(station_id, datum):
    url = "https://tidesandcurrents.noaa.gov"
    
    search_string = "/datums.html?datum="+datum+"&units=1&epoch=0&id="+str(station_id)
    return url + search_string

station_ids = [8727520, 8728690, 8729108, 8729210]
datum = "MLLW"


for station_id in station_ids:
    print(station_id, end=" ")
    #Create a handle, page, to handle the contents of the website
    page = requests.get(turl(station_id, datum))


    #Store the contents of the website under doc
    doc = lh.fromstring(page.content)
    tbodys = doc.xpath('//tbody')
    table = tbodys[0]
    tr_elements = table.getchildren()
    for T in tr_elements:
        tds = T.getchildren()
        if tds[0].text_content() == "MHHW":
            print(tds[0].text_content(), tds[1].text_content(), end=" ")
        if tds[0].text_content() == "NAVD88":
            print(tds[0].text_content(), tds[1].text_content())
