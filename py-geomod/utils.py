# This script will contain utility functions needed for the functioning of the predictor script

def driver_map_to_suitability(driver_map, land_cover_maps):
    '''
    reclassifies each driver map such that the grid cells of each
    category of the driver map are assigned a percent-developed real number, obtained by comparing the driver map to the
    beginning time land-cover map.
    '''

def create_suitability_map(list_of_driver_maps, land_cover_maps):
    '''
    GEOMOD's suitability map is created in two steps. 
    First, GEOMOD reclassifies each driver map such that the grid cells of each
    category of the driver map are assigned a percent-developed real number, obtained by comparing the driver map to the
    beginning time land-cover map. The percent-developed real number of each category in the driver map is computed as the ratio
    of the quantity of developed grid cells of that category to the quantity of all grid cells of that category.
    '''
    suitability_maps = []
    for driver_map in list_of_driver_maps:
        suitability_maps.append(driver_map_to_suitability(driver_map, land_cover_maps)) # PLEASE note: it may be better to stack them all in xarray or something
    

### Alternatively, using something like xarray, where the array is something like [map_name, height, width] with each cell containing the value for that map name at that location:

def create_suitability_map_xarray(xarray_of_driver_and_landcover_maps):
    xarray_of_suitability_maps = # do the math by relating dimensions of the xarray to each other