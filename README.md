# SNBPI

A toolbox for spatial normalization of brain PET images
## Requirements
* matlab 2020a or later
* SPM12 (https://www.fil.ion.ucl.ac.uk/spm/)
## Function
* Three methods for spatial normalization of brain PET images
   * MRI based method
   * Tempalte based method
   * Atlas based method
* Intensity normalization (SUVR)
* Extract ROI SUVR based on atlas
## Usage
Add the folder SNBPI to the path of matlab, and make sure you have already install SPM12 correctly, enter 
   ```
SNBPI
   ```
in the Matlab command line. Then a App will open.
![alt text](/SNBPI/Figures/Appmain.png "Title")

## Notice
Before performing spatial normalization, first check the origin of the image, otherwise errors may occur.The origin and direction of the image will affect the result. This is due to the nature of the unified segmentation algorithm. Therefore, the origin of the image should be placed close to the Anterior Commissure and the direction of the image should be positioned to roughly match MNI space before performing the spatial normalization.
## Author
Zhang Tianhao (张天昊)  
thzhang@ihep.ac.cn  
2021.7.29
