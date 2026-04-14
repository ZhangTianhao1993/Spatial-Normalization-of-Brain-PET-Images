# SNBPI

A comprehensive pipeline toolbox for full‑workflow brain PET image processing. 
**Citing Information:**  
Zhang Tianhao; Nie Binbin; Liu Hua; Shan Baoci; *Unified Spatial Normalization of Brain PET Image Using Adaptive Probabilistic Brain Atlas*; European Journal of Nuclear Medicine and Molecular Imaging, 2022  
[https://link.springer.com/article/10.1007/s00259-022-05752-6](https://link.springer.com/article/10.1007/s00259-022-05752-6)

## Requirements

- MATLAB 2024b or later
- SPM12 ([https://www.fil.ion.ucl.ac.uk/spm/](https://www.fil.ion.ucl.ac.uk/spm/))
- CAT12

## Installation

1. Download or clone the SNBPI repository.
2. Open MATLAB and navigate to the folder containing `setup_path.m`.
3. Run `setup_path` to add all necessary folders (excluding package folders) to the MATLAB search path and save the path permanently:
   
   ```matlab
   setup_path
   ```
4. Ensure SPM12 is correctly installed and added to the MATLAB path.

## Main Interface & Functionality

Launch the SNBPI graphical user interface by typing:

```matlab
SNBPI
```

The main window provides quick access to all processing modules:

![alt text](/SNBPI/Figures/Appmain.png "Title")

### 1. Set Origin

- **Set Origin to Centroid** – Automatically adjusts the image origin close to the anterior commissure (AC). This step is crucial for successful spatial normalization.

### 2. Spatial Normalization

Three methods are available:

- **MRI‑based**  
  PET images are co‑registered to their corresponding T1‑weighted MR images (rigid‑body, normalized mutual information). The MR images are then normalized to MNI space using Unified Segmentation in SPM12. The resulting deformation fields are applied to the co‑registered PET images.

- **Template‑based**  
  PET images are normalized by registration to a corresponding tracer‑specific template (e.g., AV45_Negative, AV45_Positive, FDG, PIB_Positive, etc.) using the SPM12 *Old Normalise* tools. Templates were constructed by averaging pre‑normalized images and smoothing with an 8‑mm Gaussian kernel.

- **Atlas‑based**  
  A three‑step algorithm:  
  
  1. Rough alignment using Unified Segmentation with standard tissue probability maps (TPM: gray matter, white matter, CSF, skin, skull, background).  
  2. Generation of an **adaptive brain probabilistic atlas** that models the individual PET intensity pattern.  
  3. Final spatial normalization using Unified Segmentation with the adaptive atlas.  
     ![flowchart](/SNBPI/Figures/flowchart.png)

### 3. Quality Check

- **Spatial Normalization Quality Check** – Evaluate the accuracy of spatial normalization by overlaying normalized images on a reference template and computing similarity metrics.

### 4. Intensity Normalization (SUVR)

- **Intensity Normalization** – Compute standardized uptake value ratios (SUVR) using either **mean** or **median** of a selected reference region.  
  Preset reference regions:  
  - Brain stem  
  - Cerebellum  
  - Gray matter in Cerebellum  
  - Cerebellum + Brain stem  
  - White matter  
  - Whole brain  
    Users can also provide custom reference masks in MNI space.

### 5. Smooth

- **Smooth** – Launches the SPM12 interactive smoothing module (Gaussian kernel) for post‑processing of normalized images.

### 6. Extract ROI Values

- **Extract ROI Values** – Extract mean/median intensity values from regions of interest defined in MNI space.  
  Preset atlases:  
  - AAL  
  - Brodmann areas  
    Custom ROI masks (in MNI space) are also supported.

## Tools Menu

Additional utilities are accessible via the **Tools** menu:

- **Atlas Merger** – Merge or manipulate atlas files.
- **Overlay Viewer** – Visualise ROI overlays on brain images.
- **Delete Files** – Batch deletion of intermediate or output files with filtering options.

## Help Menu

- **Check for Updates** – Checks online for new versions of SNBPI and notifies the user if an update is available.

## Important Notice

**Before performing spatial normalization**, verify that the image origin is placed near the anterior commissure and that the image orientation roughly matches MNI space. The Unified Segmentation algorithm is sensitive to initial positioning. Use the **Set Origin** tool to correct the origin automatically.

## Author

Zhang Tianhao (张天昊)  
[thzhang@ihep.ac.cn](mailto:thzhang@ihep.ac.cn)  
2021.7.29 (updated 2026)
