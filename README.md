# Mitochondria-structure-and-Lipid-droplets-clustering
We use Fiji, StarDist Cellpose and Ilastik to identify the structure of the mitochondria and lipid droplets clustering in cells under starvation.
## Overview
Given an image with three channels: Lipid Droplets (LDs), Mitochondria staining and Dapi, we do the following:
1. Use Cellpose to identify cells
2. Use StarDist/Cellpose to identify the LDs
3. Use Fiji to count and measure the LDs in each cell and we used Fiji’s SSIDC plugin to find LDs clustering
4. Use Ilastik to identify the mitochondria
5. Use Excel to categorize cells according to the LDs clustering and the size of the mitochondria 
## Identify cells
To identify The cells in the image:
1. First, we used a train Cellpose model (available in the Cellpose folder) for the initial segmentation (using Cellpose default parameters and setting Cell diameter to 320)
2. We then filtered out small identified cells (area smaller than 100 pixel^2)
3. Finally, we dilated the segmentation by 5 pixels (as the Cellpose model followed the outline of the mitochondria and not the actual cell membrane); We made sure that the cells dilation does not cause an overlap.
![Cell segmentation](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/b14a8658-0810-4093-b68f-0dad955bd585)

## Identify and cluster LDs
## Identify mitochondria
## Cell categorization
