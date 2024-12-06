# Script for Automated Formatting and Calculation of Image Volume Data Spreadsheet 

## Overview

Script: `save_fslstats_to_ID_list.sh`
 
This Bash script processes segmented brain image data for a set of subjects based on a list of IDs from a CSV file. It utilizes fslstats to compute various statistical measures (such as volume and mean intensity). The script is modifiable but is predefined to target image files related to brain extraction, CSF regions, and ventricles. The results are stored in a timestamped text file.
 
## Output
 
The script generates a `.txt` file containing the statistical data for each subject. The output filename includes a timestamp to ensure uniqueness.

## Requirements
 
Before running the script, ensure that you have the following installed:
 
- FSL (FMRIB Software Library)
- Bash shell (for executing the script)
- Proper directory structure and input files as specified in the script
- A CSV file containing a list of subjects, including their IDs, groups, gender, and age from which the program will read data
 
## Directory Structure
 
Before running the script, ensure your directory structure resembles the following:
 
```
/path/to/your/CT-images/
├── restore/               # Input images
├── work/                  # Working directory for intermediate files
├── suptentcsf/            # Output CSF images
├── cluster/               # Lateral Ventricle cluster analysis output
├── thirdvent/             # Third ventricle output files
```
 
## Usage
 
1. Set File Paths: Modify the script to set the correct paths for your input images, ID list, and .txt file output directories.
  
2. Run the Script: Execute the script from your terminal:
   ```bash
   bash SNImagingLab_save_fslstats_to_IDlist.sh
   ```
 
## Script Workflow

Step 1: Set directories and filenames
Configurations for input images and output files.

Step 2: Read CSV file 
Parse the list of subjects from the provided CSV file.

Step 3: Process each subject
For each subject, fslstats volume calculations are applied to the relevant image files.

Step 4: Save output
Append the statistical results to the output text file.

Step 5: Time tracking 
Track the start and end times of the script execution for performance monitoring.

## Notes
 
- The script processes each subject sequentially.
- fslstats inputs and parameters can be modified to change the statistical measures included in the output spreadsheet .txt file.
 
## Troubleshooting
 
If you encounter issues, check the following:
 
- Verify that input image files are in the correct format and location.
- Ensure the .csv file containing the list of IDs includes identifiers for all image files to be segmented and processed.
- Ensure the .csv file is formatted as follows: `ID`, `Group`, `Gender`, `Age`
- Ensure that all necessary tools and libraries are installed.
- Review script output for any error messages for guidance.
 
## License
 
This script is provided for educational and research purposes. Please attribute any usage to the original author.
 
Additionally, refer to the FSL (FMRIB Software Library) license posted at  https://fsl.fmrib.ox.ac.uk/fsl/docs/#/license

## Authors
For questions or issues, please contact the authors of this script:
* Kevin King kking@sniweb.net 
* Emily Foldes emily.foldes@barrowneuro.org



