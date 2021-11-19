# SNBPI

A toolbox for spatial normalization of brain PET images  
Please cite the original article:  
* Unified Spatial Normalization of Brain PET Image Using Adaptive Brain Probabilistic Atlas (unpublished)
## Requirements
* matlab 2020a or later
* SPM12 (https://www.fil.ion.ucl.ac.uk/spm/)
## Function
* Three methods for spatial normalization of brain PET images
   * MRI-based method  
   For MRI-based method, the PET images were first co-registered to their corresponding T1-weighted MR images by using a rigid-body model with the normalized mutual information as the objective function in SPM12. Then, the MR images were spatially normalized into MNI (Montreal Neurological Institute) space using Unified Segmentation in SPM12. The deformation fields for MR images spatial normalization were then applied to the corresponding co-registered PET images and thus the PET images were spatially normalized into MNI space using MRI-based method. 
   * Tempalte-based method  
   For template-based method, the templates (AV45_Negative, AV45_Positive, AV133_PD, AV1451_Negative, AV1451_Positive, FAltanserin, FBB_Negative, FBB_Positive, FDG, PIB_Negative, PIB_Positive) were constructed by averaging the normalized images in the template creation cohorts and smoothing the averaged images by an 8-mm Gaussian kernel. The PET images were spatially normalized by registered with the corresponding templates using SPM12 Old Normalise tools. 
   * Atlas-based method  
The atlas-based spatial normalization algorithm is divided into three steps. First, the unified segmentation algorithm in SPM12 with the TPM (Tissue Probability maps) of gray matter, white matter, CSF, skin, skull and background was used to roughly spatial normalize the PET images. Since not all PET images can be simply modeled with the TPM, this step is just used to achieve approximate alignment. Then, the adaptive brain probabilistic atlas generation algorithm was used to generate the adaptive brain probabilistic atlas for each individual PET image. The adaptive brain probabilistic atlas is used to model the voxel intensity pattern of the corresponding brain PET image.  Finally, the unified segmentation algorithm in SPM12 with the adaptive brain probabilistic atlas was used to spatial normalize each individual PET image. The flowchart of the atlas-based spatial normalization algorithm was shown below.
![alt text](/SNBPI/Figures/flowchart.png "Title")
* Intensity normalization (SUVR)  
Two methods can be selected for intensity normalization (mean and median). Six reference regions (Brain stem, Cerebellum, Gray matters in Cerebellum, Cerebellum add Brain stem, White matter, Whole brain) were preseted in the toolbox. You can also make you own reference region in MNI space for intensity normalization. 
* Extract ROI SUVR based on atlas  
Two commonly used atlas (AAL and brodmann) for human brain were preset in the toolbox. Similar, you can create you own ROI in MNI space and extrac the intensity value of the ROI regions from PET images.
## Usage
Add the folder SNBPI to the path of matlab, and make sure you have already install SPM12 correctly, enter 
   ```
SNBPI
   ```
in the Matlab command line. Then a App will open.
![alt text](/SNBPI/Figures/Appmain.png "Title")
The buttons of the three spacal normalization tools were displayed in the bottom of the main interface. The "Tools" button on the top left corner included the utility tools of "Intensity normalization" and "Extra ROI Values"
## Notice
Before performing spatial normalization, first check the origin of the image, otherwise errors may occur.The origin and direction of the image will affect the result. This is due to the nature of the unified segmentation algorithm. Therefore, the origin of the image should be placed close to the Anterior Commissure and the direction of the image should be positioned to roughly match MNI space before performing the spatial normalization.
## Author
Zhang Tianhao (张天昊)  
thzhang@ihep.ac.cn  
2021.7.29
