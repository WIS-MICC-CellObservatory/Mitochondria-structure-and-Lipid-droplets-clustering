# Mitochondria-structure-and-Lipid-droplets-clustering
We use Fiji, StarDist Cellpose and Ilastik to identify the morphology of mitochondria and number, size and pattern of lipid droplets in complete media and HBSS conditions. 
## Overview
Given an image with at least three channels: Lipid Droplets (LDs), Mitochondria staining and nucleus, we do the following:
1. Use Cellpose to identify cells
2. Use StarDist to identify the LDs
3. Use Fiji to count and measure the LDs in each cell
4. Use Fiji’s SSIDC cluster indicator plugin to identify LD clusters
5. Use Ilastik for mitochondrial segmentation
6. Use Fiji to evaluate the Aspect Ratio (AR) of mitochondrial length
7. Use Excel to categorize cells according LD pattern and mitochondrial AR.

All analysis is done on a Max intensity projection of the Z stack except the mitochondria segmentation. There we used the middle slice where the mitochondria network is most apparent.
The Fiji macro orchestrating all these steps is available at the [Fiji folder](../../tree/main/Fiji).
## Identify cells
To identify The cells in the image:
1. First, we trained a Cellpose model using both the Mitochondria and nucleus channels. The training features included cellular and nuclear areas, shape, intensity, and texture features of representative images of all different conditions, from both WT and KO group. We used Cellpose default parameters and set Cell diameter to 320. (available in the [Cellpose folder](../../tree/main/Cellpose)).
2. We then filtered out small, identified cells (area smaller than 100 micron^2)
3. Finally, we dilated the segmentation by 20 pixels (as the Cellpose model followed the outline of the mitochondria and not the actual cell membrane); We made sure that the cells dilation does not cause an overlap.
![Cell segmentation](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/b14a8658-0810-4093-b68f-0dad955bd585)
## Identify and cluster LDs
To identify the lipid droplets (LDs), we used StarDist. We then filter LDs based on their mean intensity (> 700). Finally, we filtered out too big segmentations (> 2 micron<sup>2</sup>). For StarDist we used the default parameters as set by the Fiji's plugin. 

For LD Clustering we used Fiji’s BioVoxxel plugin that implements the [SSIDC cluster indicator algorithm](https://imagej.net/plugins/biovoxxel-toolbox#:~:text=changed%20in%20future.-,SSIDC%20Cluster%20Indicator,invariant%20density%20based%20clustering%20DBSCAN).
![LD clustering](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/660f1375-b74d-4eea-ad77-3001f54c1b22), setting its Cluster distance to 20 and its density to 3.
## Identify mitochondria
To segment mitochondria, we trained an Ilastik model using representative images of all different conditions from both WT and MKO group (available in the [Ilastik folder](../../tree/main/Ilastik)).
![Mito](https://github.com/WIS-MICC-CellObservatory/Mitochondria-structure-and-Lipid-droplets-clustering/assets/64706090/f2441976-a410-4473-8be0-910907f3aaff)
## Measuring mitochondrial Aspect Ratio (AR)<sup>1</sup>
We define the Aspect ratio (AR) of the mitochondria of each cell to be the ratio between the mitochondria mean length and the mitochondria mean width. The mean width was taken to be the mean local-thickness of the mitochondria skeleton (using Fiji’s “Local Thickness” and “Skeletonize” plugins respectively), the mean length was taken to be the mitochondria mean area divided by the mean width (mean area was calculated to be the mitochondria total area divided by the number of mitochondria fragments – small fragments were ignored). Finaly, we multiplied the result by π/4 so that the AR of a circle to be 1.
## Cell categorization
For each cell in the image, we export to a CSV file the following information:
1. Number of LDs
2. LDs' average size
3. LD's average size x average intensity: We chose to use this measure rather than the size in microns as this a better way to estimate size of small organelles with actual size that is close to the microscope resolution<sup>2</sup>.
4. Number of LD clusters
5. Number of LDs in a cluster
7. The mitochondrial Aspect Ratio

We also used Excel to categorize whether a cell is “Dispersed”, “Intermediate” or “Clustered” according to the ratio between the total number of LDs and the number of clustered LDs (“Clustered” in case the ratio is above 0.7, “Intermediate” in case its between 0.7 and 0.3 and “Dispersed” in case the ratio is less than 0.3)

The Excel template used for these categorizations is available at the [Excel folder](../../tree/main/Excel).

## References
1. Luz AL, Rooney JP, Kubik LL, Gonzalez CP, Song DH, Meyer JN. Mitochondrial Morphology and Fundamental Parameters of the Mitochondrial Respiratory Chain Are Altered in Caenorhabditis elegans Strains Deficient in Mitochondrial Dynamics and Homeostasis Processes. PLoS One. 2015 Jun 24;10(6):e0130940. doi: 10.1371/journal.pone.0130940. Erratum in: PLoS One. 2016 Dec 15;11(12):e0168738. doi: 10.1371/journal.pone.0168738. PMID: 26106885; PMCID: PMC4480853.
2. Dejgaard SY, Presley JF. New Method for Quantitation of Lipid Droplet Volume From Light Microscopic Images With an Application to Determination of PAT Protein Density on the Droplet Surface. J Histochem Cytochem. 2018 Jun;66(6):447-465. doi: 10.1369/0022155417753573. Epub 2018 Jan 23. PMID: 29361239; PMCID: PMC5977440.

