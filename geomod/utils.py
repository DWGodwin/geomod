# This script will contain utility functions needed for the functioning of the predictor script

import xarray as xr
import numpy as np

def create_suitability_map_xarray(driver_maps, land_cover_map, weights=None):
    '''
    reclassifies continuous driver maps to categorical, leaves cateogorical maps as is
    NOTE: Not needed for main predictor, this will be part of the pre-predictor data preparation pipeline 
    Returns:
        categorized_driver_maps
    '''
    reclass_maps = {}
    num_bands = driver_maps.shape[0]
    for band in driver_maps['band']:
        percent_developed = {}
        bandarray = driver_maps.sel(band=band)
        band_categories = np.unique(bandarray).tolist()
        for category in band_categories:
            category_cells = bandarray == category
            developed_cells = (category_cells & (land_cover_map == 1)).sum().item()
            total_cells = category_cells.sum().item()
            percent_developed[category] = developed_cells / total_cells *100 if total_cells > 0 else 0
        reclass_maps[str(band.values)] = percent_developed
    driver_maps_as_suitability = driver_map_classification(driver_maps, reclass_maps)
    if weights:
        suitability_map = sum(driver_maps_as_suitability.sel(band=band) * weight for band, weight in weights.items())
    else:
        suitability_map = driver_maps_as_suitability.mean(dim='band')
    return suitability_map

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

  
    x_size, y_size = binary_xarray.sizes['x'], binary_xarray.sizes['y']
    borders = xr.zeros_like(binary_xarray, dtype=int)

    binary_np = binary_xarray.values
    borders_np = borders.values

    # Iterate and update using numpy arrays
    for i in range(x_size):
        for j in range(y_size):
            if binary_np[:, i, j] == 0:
                i_min, i_max = max(i - 1, 0), min(i + 2, x_size)
                j_min, j_max = max(j - 1, 0), min(j + 2, y_size)

                slice_adj = binary_np[:, i_min:i_max, j_min:j_max]

                if np.any(slice_adj == 1):
                    borders_np[:, i, j] = 1

    # Convert the numpy array back to xarray DataArray
    borders = xr.DataArray(borders_np, coords=binary_xarray.coords, dims=binary_xarray.dims)

    return borders