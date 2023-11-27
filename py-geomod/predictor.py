# This is the main module for predicting on a series of land cover maps and driver maps

class Predictor:
    '''
    Class for predicting land use maps based on historical data and driver maps

    Attributes:
        land_cover_maps (xarary): xarray datasets with pixel values 0, 1, and 2
        suitability_map (xarray): suitability map with float values
        beginning time (int): year of begin
        ending_time (int): year of end
        time_step (int): number of years between time steps 1 and 2
        pixel_quantities ([NOT SURE, int??]): projected quantity of landuse states 1 and 2 at ending time
        mask_image (xarray): binary mask of 0 and 1 to define study area
        strata_map (xarray): integer image dividing study area into regions
        constrain_to_neighborhood (int, tuple): tuple of values to constrain change to pixel neighborhood, None if no constraint
    
    Methods:

    '''