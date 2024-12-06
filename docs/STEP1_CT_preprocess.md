# CT Image Preprocessing Script
 
## Overview

Script: `ct_preprocess.sh`

This Bash script performs a series of preprocessing steps on CT images to prepare them for further analysis. The steps include reorienting the images, reslicing, smoothing, skull stripping, and bias field correction.
  
## Output
 
The primary output of interest is:
- `_restore_native`: A bias field corrected brain image using the most complete brain extraction mask.
 
## Requirements
 
Before running the script, ensure that you have the following installed:
 
- FSL (FMRIB Software Library)
- Bash shell (for executing the script)
- `iso.sh` script (from Dianne Patterson - https://bitbucket.org/dpat/tools/raw/master/LIBRARY/iso.sh)
 - Proper directory structure and input files as specified in the script

## Directory Structure
 
The script assumes the following directory structure:
 -Image Directory: parent directory
- Input Directory: `Image_dir/raw_input` (contains raw NIfTI images)
- Working Directory: ` Image_dir /work` (temporary files during processing)
- Smooth Directory: ` Image_dir /smooth` (smoothed images)
- Output Directory: `Image_dir /restore` (final output images)
 
## Usage
 
1. Update the `image_dir` variable in the script to point to your dataset's root directory.
2. Run the script in a terminal:
 
```bash
bash SNImagingLab_STEP1_ct_preprocess.sh
```

3. Monitor the terminal for processing progress and completion time.

##Script Workflow 
Step 1: Reorient to Standard Orientation
Step 2: Reslice to Isotropic 1mm x 1mm x 1mm Voxel Size
Step 3: Remove Neck Tissue
Step 4: Smooth Images
Step 5: Threshold to Remove Bone and Fat (Threshold to 120 HU)
Step 6: Skull Stripping using FSL's BET
Step 7: Bias Field Correction using FSL's FAST

## Notes

Parallel Processing
The script is designed to run multiple jobs in parallel to optimize processing time. You can adjust the number of concurrent jobs by changing the value of N in the script.

The script processes files matching the pattern *bwct*.nii.gz within the input directory. Modify this pattern as necessary to include other file types.

Temporary files created during processing will be cleaned up automatically at the end of the script.

## Resources

For additional processing tips and best practices, refer to the following resources:
Neuroimaging Core Documentation https://neuroimaging-core-docs.readthedocs.io/en/latest/

## License

This script is provided for educational and research purposes. Please attribute any usage to the original author.

Additionally, refer to the FSL (FMRIB Software Library) license posted at  https://fsl.fmrib.ox.ac.uk/fsl/docs/#/license

## Authors
For questions or issues, please contact the authors of this script:
Kevin King kking@sniweb.net 
Emily Foldes emily.foldes@barrowneuro.org

