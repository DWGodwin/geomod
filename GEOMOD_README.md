# GEOMOD Project 
This project aims to predict land use maps based on historical data and various driver maps. The primary objectives include developing a model for predicting land use changes, calculating a suitability map, and validating the predictions against a reference map.

## Project Rationale 
The project addresses the need for accurate land use predictions, considering the influence of various categorical and continuous driver maps. The model calculates a suitability map, providing insights into areas most suitable for development. Validation against a reference map ensures the accuracy and reliability of the predictions.

## Getting Started 
### Prerequisites 
Ensure you have the required libraries installed:
```
pip install xarray numpy scipy
```
## operation ##
### 1. Data Preparation: 

Prepare datasets for land cover maps at the beginning and ending time steps.
Gather categorical and continuous driver maps influencing land use changes.
Obtain or create a validation map for performance evaluation.

### 2. Predictor Initialization: 
from land_use_predictor import Predictor

```python linenos
predictor = Predictor(
    land_cover_map,
    beginning_time,
    ending_time,
    time_step,
    suitability_map=None,
    driver_maps=None,
    validation_map=None,
    pixel_quantities=None,
    mask_image=None,
    strata_map=None,
    constrain_to_neighborhood=None,
    driver_map_weights=None
)
```
### 3. Suitability Map: 
```python
# If suitability_map is not provided, it will be calculated using the provided parameters.
predictor.suitability_map = predictor.calculate_suitability_map()
```
### 4. Land Use Prediction:
```
predicted_map = predictor.predict()
```
### 5. Validation:
```
performance_table, validation_map = predictor.validate()
```
### 6. Results

### 7. Considerations
. Adjust parameters such as weights, neighborhood constraints, and pixel quantities to optimize predictions.
. Explore and experiment with different interpolation methods for driver maps.
