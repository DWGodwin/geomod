### Implementing GEOMOD in Python for Land Cover Prediction

This module replicates the functionality of Terrset's GEOMOD tool for predicting land cover change. GEOMOD, a land-use change model developed by Pontius et al. in 2001, simulates transitions between two states, emphasizing both quantity and spatial distribution of change.

### A note on changing tied cells:

Due to the nature of binning input maps to create a suitability map, there will often be cells with the same probability of conversion at the change threshold. Geomod must decide which of these cells to convert. Geomod2 as implemented in Terrset used a method whereby each nth cell was chosen, distributing change evenly across tied cells semi-randomly (GEOMOD.FOR lines 1508-1533). However, we decide to fit a polynomial function to input maps, eliminating this issue by creating a truly continuous suitability map.

