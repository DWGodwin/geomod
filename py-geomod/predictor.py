# This is the main module for predicting on a series of land cover maps and driver maps
from . import utils

class Predictor:
    '''
    Class for predicting land use maps based on historical data and driver maps

    Attributes:
        land_cover_map (xarary): xarray datasets with pixel values 0, 1, and 2, where 0 is masked pixels
        suitability_map (xarray): suitability map with float values from 0-100, leaving as None triggers caculation of suitability map from drivers
        driver_maps (xarray): stack of categorical driver maps that the module will use to calculate a suitabilty map if suitability_map = None
        validation_map (xarray): xarray datasets with pixel values 0, 1, and 2, where 0 is masked pixels, for ending time step
        beginning time (int): year of begin
        ending_time (int): year of end
        time_step (int): number of years between time steps 1 and 2
        pixel_quantities (tuple, int): projected quantity of landuse states 1 and 2 at ending time, if None, calculates based on validation_map
        mask_image (xarray): binary mask of 0 and 1 to define study area
        strata_map (xarray): integer image dividing study area into regions
        constrain_to_neighborhood (int, tuple): tuple of values to constrain change to pixel neighborhood, None if no constraint
        driver_map_weights (dict): set of weights representing the amount to weight each driver map {map_name: weight, map_name2 : weight2}, if None, equal weights
    
    Methods:

    '''
    def __init__(self, land_cover_map, suitability_map=None, driver_maps=None, ):
        # define all the attributes and stuff
        self.land_cover_map = land_cover_map
        self.driver_maps = driver_maps
        if suitability_map = None:
            suitability_map = utils.create_suitability_map(self.land_cover_map, self.driver_maps, self.driver_map_weights, self.strata_map)
    
    def predict(self):
        '''
        Take start year, starting binary classification map, suitability map, and decision rule, return predicted classification map
        THIS IS THE FUNCTION THAT SELECTS CELLS BASED ON SUITABILITY
        '''

    def validate(self): 
        '''
        calls CROSSTAB
        returns table and map
        '''


        