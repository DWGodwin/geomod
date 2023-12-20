from . import utils
import xarray as xr
import numpy as np

class Predictor:
    '''
    Class for predicting land use maps based on historical data and driver maps

    Attributes:
        land_cover_map (xarray): xarray datasets with pixel values 0 and 1, where masked pixels are np.nan
        beginning time (int): year of begin
        ending_time (int): year of end
        time_step (int): number of time steps to generate
        suitability_map (xarray): suitability map with float values from 0-100, leaving as None triggers caculation of suitability map from drivers
        driver_maps (xarray): stack of categorical driver maps that the module will use to calculate a suitabilty map if suitability_map = None
        validation_map (xarray): xarray datasets with pixel values 0 and 1, where masked pixels are np.nan, for ending time step
        pixel_quantities (tuple, int): projected quantity of landuse states 0 and 1 at ending time, if None, calculates based on validation_map
        strata_map (xarray): integer image dividing study area into regions
        constrain_to_neighborhood (int, tuple): tuple of values to constrain change to pixel neighborhood, None if no constraint. If the neighborhood is too small, Geomod will automatically try larger neighborhoods until desired change quantity is acheived
        driver_map_weights (dict): set of weights representing the amount to weight each driver map {map_name: weight, map_name2 : weight2}, if None, equal weights
    
    Methods:
    '''
    def __init__(
        self, 
        land_cover_map, 
        beginning_time,
        ending_time,
        time_step=1,
        suitability_map=None, 
        driver_maps=None, 
        validation_map=None,
        pixel_quantities=None,
        mask_image=None,
        strata_map=None,
        constrain_to_neighborhood=None,
        driver_map_weights=None
        ):

        self.land_cover_map = land_cover_map
        self.driver_maps = driver_maps
        self.suitability_map = suitability_map
        self.validation_map = validation_map
        self.pixel_quantities = pixel_quantities
        self.starting_pixel_quantities = utils.get_pixel_quantities(land_cover_map)
        self.mask_image = mask_image
        self.strata_map = strata_map
        self.constrain_to_neighborhood = constrain_to_neighborhood
        self.driver_map_weights = driver_map_weights

        if self.suitability_map is None:
            self.suitability_map = utils.create_suitability_map(self.driver_maps, self.land_cover_map, self.driver_map_weights)
            
        if self.pixel_quantities is None:
            self.pixel_quantities = utils.get_pixel_quantities(validation_map)
        
        
    def predict(self):
        '''
        Predict land use maps based on the provided parameters.

        Parameters:
            None

        Returns:
            xarray: Predicted classification map.
        '''
        # Step 1: Mask pixels already developed in the land cover map out of the suitability map
        change_pixel_quantity = self.pixel_quantities[0] -  self.starting_pixel_quantities[0]
        print('target number of change pixels:', change_pixel_quantity)

        
        if self.constrain_to_neighborhood:
            neighborhood_constraint = list(self.constrain_to_neighborhood)
            changeable_count = 0
            
            while(changeable_count < change_pixel_quantity):
                changeable_candidates = utils.get_edges(self.land_cover_map, neighborhood_constraint)
                changeable_count = changeable_candidates.sum().item()
                if changeable_count < change_pixel_quantity:
                    neighborhood_constraint[0] += 1
                    neighborhood_constraint[1] += 1
                
            print ('Final neighborhood constraint:', neighborhood_constraint)
            print ('The number of pixels that can be changed:', changeable_count)
        else:
            changeable_candidates = xr.where(self.land_cover_map==0, 1, 0)
            changeable_count = changeable_candidates.sum().item()
            print ('Not using neighborhood constraint')
            print ('The number of pixels that can be changed:', changeable_count)

        # get a map of suitability only on pixels that are not developed
        suitability_change_xr = xr.where(changeable_candidates==1, self.suitability_map, np.nan)
        
        # get the threshold above which there are the number of pixels we defined a change_pixel_quantity
        suitability_threshold = suitability_change_xr.quantile(q = 1 - (change_pixel_quantity/changeable_count), skipna=True).values

        # define which pixels will be changed - only those above the change threshold
        change_pixels = xr.where(suitability_change_xr > suitability_threshold, 1, 0)
        change_pixels_count = change_pixels.sum().item()

        # find the total number of changed pixels - it should match change_pixel_quantity!
        print("Number of pixels above the change threshold:", change_pixels_count)
        
        if change_pixels_count < change_pixel_quantity:
            tied_pixels = xr.where(suitability_change_xr == suitability_threshold, 1, 0)
            tied_pixel_quantity = tied_pixels.sum().item()
            subset_quantity = change_pixel_quantity - change_pixels_count
            print("There are", tied_pixel_quantity, "tied pixels, of which", subset_quantity, "must be selected arbitrarily.")
            print("If this is unacceptable, consider reducing tied pixels by using more categorical variables to generate your suitability map")
            subset = utils.get_tied_pixel_subset(tied_pixels, tied_pixel_quantity, subset_quantity)
            change_pixels = change_pixels + subset
        
        self.predicted_map = self.land_cover_map + change_pixels
            
    def validate(self):
        '''
        Validate the predicted land use maps.

        Returns:
            dict: Table of performance metrics.
            xarray: Validation map.
        '''
        
        performance_table = utils.CROSSTAB(self.land_cover_map, self.predicted_map, self.validation_map)

        #validation_map = utils.validate(self.predicted_map, self.validation_map)

        return performance_table#, validation_map