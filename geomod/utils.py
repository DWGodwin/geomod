import xarray as xr
import numpy as np

def create_suitability_map(driver_maps, land_cover_map, weights=None):
    '''
    reclassifies continuous driver maps to categorical, leaves categorical maps as is
    NOTE: Not needed for the main predictor; this will be part of the pre-predictor data preparation pipeline 
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
            percent_developed[category] = developed_cells / total_cells * 100 if total_cells > 0 else 0
        reclass_maps[str(band.values)] = percent_developed

    # Corrected function name
    driver_maps_as_suitability = driver_map_classification(driver_maps, reclass_maps)

    if weights:
        suitability_map = sum(driver_maps_as_suitability.sel(band=band) * weight for band, weight in weights.items())
    else:
        suitability_map = driver_maps_as_suitability.mean(dim='band')
    return suitability_map

def driver_map_classification(driver_maps, reclass_maps):
    '''
    Reclassify continuous driver maps to categorical, leaving categorical maps as is.

    Parameters:
        driver_maps (xarray.DataArray): Input continuous driver maps.
        reclass_maps (dict): Dictionary containing reclassification rules for each band.

    Returns:
        xarray.DataArray: Reclassified driver maps.
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
    Returns a table of hits, false alarms, correct rejections, misses, built loss, built persistence (for example).

    Compares the three maps for validation.

    Parameters:
        land_cover_map (xarray.DataArray): Reference land cover map.
        predicted_map (xarray.DataArray): Predicted land cover map.
        validation_map (xarray.DataArray): Ground truth validation map.

    Returns:
        dict: Table of performance metrics.
    '''
    tp = np.sum((predicted_map == 1) & (validation_map == 1))
    tn = np.sum((predicted_map == 0) & (validation_map == 0))
    fp = np.sum((predicted_map == 1) & (validation_map == 0))
    fn = np.sum((predicted_map == 0) & (validation_map == 1))

    # Calculate metrics
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0

    # Build the metrics table
    metrics = {
        'True Positives': tp.item(),
        'True Negatives': tn.item(),
        'False Positives': fp.item(),
        'False Negatives': fn.item(),
        'Precision': precision.item(),
        'Recall': recall.item(),
        'F1 Score': f1_score.item(),
    }

    return metrics

def reclassify_landcover_map(land_cover_map, class_of_interest):
    '''
    Reclassifies a land cover map based on the provided class code.

    Parameters:
        land_cover_map (xarray.DataArray): Input land cover map.
        class_of_interest (int): Class code to reclassify to.

    Returns:
        xarray.DataArray: Reclassified land cover map.
    '''
    land_cover_map_reclass = xr.where(land_cover_map == class_of_interest, 1, 0)
    land_cover_map_reclass = xr.where(land_cover_map.isnull(), np.nan, land_cover_map_reclass)
    return land_cover_map_reclass

def get_edges(binary_xarray, neighborhood_constraint):
    '''
    Extracts edges from a binary xarray based on the specified neighborhood constraint.

    Parameters:
        binary_xarray (xarray.DataArray): Binary input array.
        constrain_to_neighborhood (tuple): Tuple of values to constrain change to pixel neighborhood.

    Returns:
        xarray.DataArray: Extracted edges.
    '''
    x, y = neighborhood_constraint # kernel dimension x and kernel dimension y

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

def get_pixel_quantities(binary_xarray):
    '''
    Extracts the number of developed and undeveloped cells of an input map

    Parameters:
        input_map (xarray.DataArray): Binary input array.

    Returns:
        tuple, int: (number of ones, number of zeros)
    '''
    ones_count = binary_xarray.sum().item()
    zeroes = xr.where(binary_xarray==0, 1, 0)
    zeroes_count = zeroes.sum().item()
    
    return(ones_count, zeroes_count)
           
def get_tied_pixel_subset(tied_pixels, tied_pixel_quantity, subset_quantity):
    '''
    Gets an arbitrary subset of a binary xarray of tied pixels.

    Parameters:
        tied_pixels (xarray.DataArray): Binary input array.
        tied_pixel_quantity (int): the number of tied pixels
        subset_quantity (int): the number of pixels in the desired subset
    
    Returns:
        subset (xarray.DataArray): the arbitrary subset of the input array
    '''
    np.random.seed(950)
    random_distribution = np.random.uniform(0, 1, tied_pixels.shape)
    tied_random = xr.where(tied_pixels==1, tied_pixels*random_distribution, np.nan)
    threshold = tied_random.quantile(q = 1 - (subset_quantity/tied_pixel_quantity), skipna=True).values
    random_subset = xr.where(tied_random > threshold, 1, 0)
    return random_subset