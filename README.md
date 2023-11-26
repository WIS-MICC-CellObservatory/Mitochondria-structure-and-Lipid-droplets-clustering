# Mitochondria-structure-and-Lipid-droplets-clustering
We use Fiji, StarDist Cellpose and Ilastik to identify the structure of the mitochondria and lipid droplets clustering in cells under starvation. 
## Overview
Given an image with at least three channels: Lipid Droplets (LDs), Mitochondria staining and Dapi, we do the following:
1. Use Cellpose to identify cells
2. Use StarDist/Cellpose to identify the LDs
3. Use Fiji to count and measure the LDs in each cell
4. Use Fiji’s SSIDC cluster indicator plugin to identify LD clusters
5. Use Ilastik to identify the mitochondria
6. Use Excel to categorize cells according to the LDs clustering and the size of the mitochondria
All analysis is done on a Max intensity projection of the Z stack except the mitochondria segmentation. There we used the middle slice (4th slice out of 7)

The Fiji macro orchestrating all these steps is available at the [Fiji folder](../../tree/main/Fiji).
## Identify cells
To identify The cells in the image:
1. First, we trained a Cellpose model using both the Mitochondria and Dapi channels. The training features included cellular and nuclear areas, shape, intensity, and texture features of representative images of all different conditions, from both WT and KO group. We used Cellpose default parameters and set Cell diameter to 320. (available in the [Cellpose folder](../../tree/main/Cellpose)).
2. We then filtered out small, identified cells (area smaller than 100 micron^2)
3. Finally, we dilated the segmentation by 5 pixels (as the Cellpose model followed the outline of the mitochondria and not the actual cell membrane); We made sure that the cells dilation does not cause an overlap.
![Cell segmentation](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/b14a8658-0810-4093-b68f-0dad955bd585)
## Identify and cluster LDs
To identify the lipid droplets (LDs), we used StarDist for the MTCH2 KO group. For the WT group, we used StarDist or Cellpose alternatively as at some time points (early hours of post-media change), the LDs have low intensity and StarDist fails to identify them. Cellpose segmentation is better at identifying the LDs at these time points, but still have high false positives. To avoid these false positives, we filter LDs based on their mean intensity (keeping only the top 10-20%). For Cellpose we used its default parameters and the out-of-the-box 'cyto2' model, setting cell diameter to 7.5. We then filtered out too big identified LDs (> 3 micron^2). For StarDist we used the default parameters as set by the Fiji's plugin. 

For LD Clustering we used Fiji’s BioVoxxel plugin that implements the [SSIDC cluster indicator algorithm](https://imagej.net/plugins/biovoxxel-toolbox#:~:text=changed%20in%20future.-,SSIDC%20Cluster%20Indicator,invariant%20density%20based%20clustering%20DBSCAN).
![LD clustering](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/660f1375-b74d-4eea-ad77-3001f54c1b22), setting its Cluster distance to 20 and its density to 3.
## Identify mitochondria
To segment mitochondria, we trained an Ilastik model using representative images of all different conditions from both WT and KO group (available in the [Ilastik folder](../../tree/main/Ilastik)).
![Mito](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/f2441976-a410-4473-8be0-910907f3aaff)
## Cell categorization
For each cell in the image, we export to a CSV file the following information:
1. Number of LDs
2. LDs' average size
3. Number of clusters
4. Number of clustered LDs
5. The total area of the mitochondria
6. The area size of the fragmented (fragments less than 1.5 micron^2), intermediate (fragments between 1.5 and 4 micron^2), elongated (fragments between 4 and 14 micron^2), and hyper elongated (fragments bigger than 14 micron ^2) mitochondria.

We then used Excel to categorize whether a cell is “Fragmented”, “Intermediate”, “Elongated” or “Hyper elongated” according to where most of its mitochondria area resides.

We also used Excel to categorize whether a cell is “Dispersed”, “Intermediate” or “Clustered” according to the ratio between the total number of LDs and the number of clustered LDs (“Clustered” in case the ratio is above 0.7, “Intermediate” in case its between 0.7 and 0.3 and “Dispersed” in case the ratio is less than 0.3)

The Excel template used for these categorizations is available at the [Excel folder](../../tree/main/Excel).
