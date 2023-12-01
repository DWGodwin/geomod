# This script will contain utility functions needed for the functioning of the predictor script




def driver_map_to_suitability(categorized_driver_maps, land_cover_map):
    '''
    reclassifies each driver map such that the grid cells of each
    category of the driver map are assigned a percent-developed real number, obtained by comparing the driver map to the
    beginning time land-cover map.
    '''

def create_suitability_map(list_of_categorized_driver_maps, driver_map_weights, land_cover_map, strata_map):
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

def create_suitability_map_xarray(xarray_of__categorized_driver_and_landcover_maps):
    xarray_of_suitability_maps = None # do the math by relating dimensions of the xarray to each other




def driver_map_classification(driver_maps):
    '''
    reclassifies continuous driver maps to categorical, leaves cateogorical maps as is
    NOTE: Not needed for main predictor, this will be part of the pre-predictor data preparation pipeline 
    Returns:
        categorized_driver_maps
    '''

def CROSSTAB(land_cover_map, predicted_map, validation_map):
    '''
    returns a table of hits, false alarms, correct rejections, misses, built loss, built persistence (for example)

    compares the three maps for validation
    '''
    
def reclassify_landcover_map(land_cover_map, class_of_interest):
    '''
    gets a land cover map and class code of interest and reclassifies to 1 (non-class) and 2 (class)
    '''
    developed_map = (land_cover_map.where(land_cover_map==class_of_interest) / land_cover_map) * 2
    non_developed_map = land_cover_map.where(land_cover_map!=class_of_interest) / land_cover_map
    land_cover_map_reclass = developed_map.where(developed_map==2, non_developed_map)
    return land_cover_map_reclass

def get_edges(binary_xarray, constrain_to_nieghborhood):

    # m
    
    borders = xr.zeros_like(class_array, dtype=int)

    # Get the size of the input array in both dimensions
    x_size, y_size = class_array.sizes['x'], class_array.sizes['y']

    # Iterate through each value
    for i in range(x_size):
        for j in range(y_size):
            # Select those which are in class 1
            if class_array.loc[i, j] == 1:
                # Define the range for slicing, handling edge cases
                i_min, i_max = max(i-1, 0), min(i+2, x_size)
                j_min, j_max = max(j-1, 0), min(j+2, y_size)

                # Get slice of all adjacent pixels
                slice_adj = class_array.loc[i_min:i_max, j_min:j_max]

                # Check if any belong to class 2
                if np.any(slice_adj == 2):
                    # Update borders array
                    borders.loc[i, j] = 1