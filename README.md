### Implementing GEOMOD in Python for Land Cover Prediction

This module replicates the functionality of Terrset's GEOMOD tool for predicting land cover change. GEOMOD, a land-use change model developed by Pontius et al. in 2001, simulates transitions between two states, emphasizing both quantity and spatial distribution of change.

### Current Functionality:

12/20
Examples of the module's use can be found in predict-example.ipynb, given categorical land cover maps and driver maps. Users can initialize a model as a class of Predictor, using as input driver maps, categorical land cover maps, an optional neighborhood search parameter, and optional driver map weights.

### Intended Improvements, in order of priority:

- Addressing CROSSTAB issue where true positives and false negatives are equal
- Creation of a validation map comparing time step 1, predicted time step 2, and validation time step 2
- Generation of intermediate time steps between time step 1 and 2
- Testing on larger datasets
- Modifications to model fluctuating land use change
