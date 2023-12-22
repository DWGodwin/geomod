# GEOMOD Project 
This module replicates the functionality of Terrset's GEOMOD tool for predicting land cover change. GEOMOD, a land-use change model developed by Pontius et al. in 2001, simulates transitions between two states, emphasizing both quantity and spatial distribution of change.
This project aims to predict land use maps based on historical data and various driver maps. The module encompasses functions for land cover mapping, reclassification of continuous driver maps, and model performance assessment. Additionally, a Predictor, is introduced for predicting land use maps based on historical data and driver maps, calculating suitability maps, and validating predictions against reference maps.

## Project Rationale 
The open-source Python module presents significant advantages over proprietary alternatives like Terrset. Its collaborative and community-driven development allows users to contribute and enhance functionality, ensuring the tool remains relevant and up-to-date in the geospatial analysis community. The elimination of licensing fees makes it a cost-effective and accessible alternative for a broad audience, particularly benefiting researchers in academic and non-profit settings. The module's integration capabilities with existing Python workflows and compatibility with popular scientific computing libraries such as NumPy, SciPy, and xarray enhance efficiency, ease of use, and scalability. Overall, these qualities position the module as a versatile and accessible tool, making it an attractive choice for researchers, academics, and professionals seeking a flexible and collaborative environment for accurate land use predictions and geospatial analysis.


## Getting Started 
The project aims to fulfill the demand for land use predictions by taking into account the impact of categorical driver maps. The model systematically computes a suitability map, offering valuable insights into regions that are most conducive for development. Rigorous validation against a reference map is conducted to guarantee the precision and dependability of the predictions.
### Prerequisites 
Ensure you have the required libraries installed:
```
pip install xarray numpy scipy
```
## operation ##
### 1. Data Preparation: 

Prepare datasets for land cover maps at the beginning and ending time steps.
Gather categorical driver maps influencing land use changes.
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
GEOMOD Python module offer a robust and versatile toolkit for geospatial analysis. The module provide essential capabilities for preprocessing, reclassification, and evaluation, while the Predictor streamlines the entire land use prediction workflow. 
### 7. Considerations
- Adjust parameters such as weights, neighborhood constraints, and pixel quantities to optimize predictions.
- Explore and experiment with different interpolation methods for driver maps.
