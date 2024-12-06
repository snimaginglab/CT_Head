# Freesurfer for Brain Segmentation in CT Scans

This is a Freesurfer-based pipeline of Bash scripts, which orients, smooths, and segments CT images of the human brain. The pipeline consists of 3 steps, each of which with their own Bash script:
1. CT preprocessing
2. CT segmentation (for which there are two scripts to choose from with different thresholds)
3. calculate stats (volume, mean intensity, etc.)

## Authors

Emily Foldes (emily.foldes@barrowneuro.org)
Jacob Knittel (jacobknittle@creighton.edu)
Dr. Kevin King (kking@sniweb.net)
SNI Imaging Lab

## Requirements

- [FSL (FMRIB Software Library)](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/index)
- Bash shell
- `iso.sh` script ([from Dianne Patterson](https://bitbucket.org/dpat/tools/raw/master/LIBRARY/iso.sh))
- an [FSL license](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/license) (free)

## Usage

The scripts should be run in the following order:
```
ct_preprocess.sh
ct_segmentation.sh  (OR ct_segmentation_t24.sh)
save_fslstats_to_ID_list.sh
```

## Setup

1. Make sure you have a Bash shell. Mac OS and Linux have Bash pre-installed. Windows users can get Bash through the [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/install).
2. Install [FSL](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/index)
3. Acquire Dianne Patterson's `iso.sh` script ([linked here](https://bitbucket.org/dpat/tools/raw/master/LIBRARY/iso.sh))
4. Create the following folders and sub-folders
```
/path/to/your/CT-images/
├── restore/               # Input images
├── work/                  # Working directory for intermediate files
├── suptentcsf/            # Output CSF images
├── cluster/               # Lateral Ventricle cluster analysis output
├── thirdvent/             # Third ventricle output files


Image_dir/
├── restore/               # Input images
├── work/                  # Working directory for intermediate files
├── omat/                  # Transformation matrices
├── interim_vent/          # Intermediate ventricle images
├── suptentcsf/            # Output CSF images
├── cluster/               # Cluster analysis output
├── thirdvent/             # Third ventricle output files
└── stdorient/             # Final vent images in standard orientation

```

## License

This software involves two separate licenses. One is a [Creative Commons BY-NC-ND 4.0 license](https://creativecommons.org/licenses/by-nc-nd/4.0/deed.en) for the shell scripts in this repository. The other is the license inherent to FSL (FMRIB Software Library), [which can be accessed here](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/license).

