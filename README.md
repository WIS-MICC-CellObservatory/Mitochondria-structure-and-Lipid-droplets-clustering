# Mitochondria-structure-and-Lipid-droplets-clustering
We use FIji, Stardist Cellpose and Ilastik to identify the structure of the mitochondria and lipid droplets clustering in cells under starvation
## Overview
Given an image with three channels: Lipid Droplets (LDs), Litosomes, and Mitocondria stainings, we do the following:
1. Use Cellpose to idenitify cells
2. Use Stardist/Cellpose to identify the LDs
3. Use Fiji to count and measure the LDs in each cell and we used FIjis's SSIDC plugin to find LDs clustering
4. Use Ilastik to identify the mitochondria
5. Use Excel to categorize cells according to the LDs clustering and the size of the mitochondria 
## Identify cells
To identify The cells in the image we used Cellpose's "cyto2" 
## Identify and cluster LDs
## Identify mitochondria
## Cell categorization
