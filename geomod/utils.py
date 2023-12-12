# This script will contain utility functions needed for the functioning of the predictor script

import xarray as xr
import numpy as np
from numpy.polynomial import Polynomial
from scipy.interpolate import interp1d

def create_suitability_map_xarray(driver_maps_discrete, driver_maps_continuous, land_cover_map, interpolation='linear', weights=None):
    '''
    reclassifies continuous driver maps to categorical, leaves cateogorical maps as is
    NOTE: Not needed for main predictor, this will be part of the pre-predictor data preparation pipeline 
    Returns:
        categorized_driver_maps
    '''
    reclass_maps = {}
    num_bands = driver_maps_discrete.shape[0]
    
    for band in driver_maps_discrete['band']:
        percent_developed = {}
        bandarray = driver_maps_discrete.sel(band=band)
        band_categories = np.unique(bandarray).tolist()
        for category in band_categories:
            category_cells = bandarray == category
            developed_cells = (category_cells & (land_cover_map == 1)).sum().item()
            total_cells = category_cells.sum().item()
            percent_developed[category] = developed_cells / total_cells *100 if total_cells > 0 else 0
        reclass_maps[str(band.values)] = percent_developed
    
    if interpolation == 'polynomial':
        interpolation_functions = {key: Polynomial.fit(list(value.keys()), list(value.values()), 20) for key, value in reclass_maps.items()}
    elif interpolation == 'linear':
        interpolation_functions = {key: interp1d(list(value.keys()), list(value.values()), fill_value='extrapolate') for key, value in reclass_maps.items()}

    driver_maps_as_suitability = driver_map_imterpolation(driver_maps_continuous, interpolation_functions)

    if weights:
        suitability_map = sum(driver_maps_as_suitability.sel(band=band) * weight for band, weight in weights.items())
    else:
        suitability_map = driver_maps_as_suitability.mean(dim='band')
    return suitability_map

def driver_map_imterpolation(driver_maps, interpolation_functions):
    '''
    interpolaties continuous driver maps using suitability functions derived through interpolation
    Returns:
        interpolated_driver_maps
    '''
    interpolated_bands = []
    
    for band, interpolation_fn in interpolation_functions.items():
        interp_band = driver_maps.sel(band=band)
        
        interpolated_band = interpolation_fn(interp_band)
        
        interpolated_bands.append(interpolated_band)
    numpy_maps = np.stack(interpolated_bands)
    interpolated_driver_maps = xr.DataArray(numpy_maps, 
                               dims=driver_maps.dims,
                               coords=driver_maps.coords,
                               attrs=driver_maps.attrs)
    
                            
    return interpolated_driver_maps

def driver_map_classification(driver_maps, reclass_maps):
    '''
    reclassifies continuous driver maps to categorical, leaves cateogorical maps as is
    NOTE: Not needed for main predictor, this will be part of the pre-predictor data preparation pipeline 
    Returns:
        categorized_driver_maps
    '''
    reclassified_bands = []

    # Step 2 & 3: Apply the reclassification rules for each band
    for band, reclass_map in reclass_maps.items():
        reclass_band = driver_maps.sel(band=band)
        reclassified_band = reclass_band.copy()

        for old_values, new_value in reclass_map.items():
            reclassified_band = xr.where(reclassified_band.isin(old_values), new_value, reclassified_band)

        reclassified_bands.append(reclassified_band)

    # Combine reclassified bands into a single dataset
    reclassified_driver_maps = xr.concat(reclassified_bands, dim='band')

    return reclassified_driver_maps
            

def CROSSTAB(land_cover_map, predicted_map, validation_map):
    '''
    returns a table of hits, false alarms, correct rejections, misses, built loss, built persistence (for example)

    compares the three maps for validation
    '''
    
def reclassify_landcover_map(land_cover_map, class_of_interest):
    '''
    gets a land cover map and class code of interest and reclassifies to 0 (non-class) and 1 (class)
    '''
    land_cover_map_reclass = xr.where(land_cover_map==class_of_interest, 1, 0)
    land_cover_map_reclass = xr.where(land_cover_map.isnull(), np.nan, land_cover_map_reclass)
    return land_cover_map_reclass

def get_edges(binary_xarray, constrain_to_nieghborhood):

    x, y = constrain_to_nieghborhood # kernel dimension x and kernel dimension y

    x_size, y_size = binary_xarray.sizes['x'], binary_xarray.sizes['y']
    borders = xr.zeros_like(binary_xarray, dtype=int)

    binary_np = binary_xarray.values
    borders_np = borders.values
    
    # Iterate and update using numpy arrays
    for i in range(x_size):
        for j in range(y_size):
            if binary_np[:, i, j] == 0:
                i_min, i_max = max(i - int(x/2), 0), min(i + int(x/2)+1, x_size)
                j_min, j_max = max(j - int(y/2), 0), min(j + int(y/2)+1, y_size)

                slice_adj = binary_np[:, i_min:i_max, j_min:j_max]

                if np.any(slice_adj == 1):
                    borders_np[:, i, j] = 1

    # Convert the numpy array back to xarray DataArray
    borders = xr.DataArray(borders_np, coords=binary_xarray.coords, dims=binary_xarray.dims)

    return borders