# This is the main module for predicting on a series of land cover maps and driver maps
from . import utils

class Predictor:
    '''
    Class for predicting land use maps based on historical data and driver maps

    Attributes:
        land_cover_map (xarary): xarray datasets with pixel values 0, 1, and 2, where 0 is masked pixels
        beginning time (int): year of begin
        ending_time (int): year of end
        time_step (int): number of years between time steps 1 and 2
        suitability_map (xarray): suitability map with float values from 0-100, leaving as None triggers caculation of suitability map from drivers
        driver_maps (xarray): stack of categorical driver maps that the module will use to calculate a suitabilty map if suitability_map = None
        validation_map (xarray): xarray datasets with pixel values 0, 1, and 2, where 0 is masked pixels, for ending time step
        pixel_quantities (tuple, int): projected quantity of landuse states 1 and 2 at ending time, if None, calculates based on validation_map
        mask_image (xarray): binary mask of 0 and 1 to define study area
        strata_map (xarray): integer image dividing study area into regions
        constrain_to_neighborhood (int, tuple): tuple of values to constrain change to pixel neighborhood, None if no constraint
        driver_map_weights (dict): set of weights representing the amount to weight each driver map {map_name: weight, map_name2 : weight2}, if None, equal weights
    
    Methods:

    '''
    def __init__(
        self, 
        land_cover_map, 
        beginning_time,
        ending_time,
        time_step,
        suitability_map=None, 
        driver_maps=None, 
        validation_map=None,
        pixel_quantities=None,
        mask_image=None,
        strate_map=None,
        constrain_to_neighborhood=None,
        driver_map_weights=None
        ):
        # define all the attributes and stuff
        self.land_cover_map = land_cover_map
        self.driver_maps = driver_maps
        if suitability_map == None:
            suitability_map = utils.create_suitability_map(self.land_cover_map, self.driver_maps, self.driver_map_weights, self.strata_map)
    
    def predict(self):
        '''
        Take start year, starting binary classification map, suitability map, and decision rule, return predicted classification map
        THIS IS THE FUNCTION THAT SELECTS CELLS BASED ON SUITABILITY
        
        If constrain_to_neighborhoods is None, the method:
        1. masks pixels which are already developed in the land cover map out of the suitability map
        2. reclasses the suitability map so that [pixel quantity] number of pixels are reclassified as 2, the rest as 1.
        3. combines the reclassed suitability map (which represents the change prediction) with the original land cover map.
        
        If constrain_to_neighborhoods is e.g. (3x3):
        1. masks pixels which are already developed in the land cover map out the suitability map
        2. masks non-border pixels out of the masked suitability map
        3. finds the [pixel quantity] number of pixels of the border suitability map that are
        '''

    def validate(self): 
        '''
        calls CROSSTAB
        returns table and map
        '''


        