#!/bin/bash

##This script applies registration and masking techniques to brain extracted images from preprocessed Head CT.
#The outputs include segmented csf and ventricles:
# 1. register extracted and preprocessed _restore brain to the SRI24 standard brain atlas
# 2. create supratentorial CSF
# 2a. apply slight erosion to remove halo affect of volume averaging added during registration
# 2b. apply threshold to extract CSF voxels (0 - 24HU)
# 2c. isolate narrowed region of CSF to limit subarachnoid CSF captured by NPH-shaped ventriculomegaly mask
# 2d. (optional) create suprasylvian subarachnoid (SA) CSF using SRI tzo116plus mask modified for superior-frontal SA brain regions
# 3. align ventricle atlases to central portion of CSF
# 3a. create a "crude" ventricle to use as a target for aligning the ventricle atlases by extracting CSF only in the region of the lateral ventricles
# 3b. register both ventriculomegaly (big) atlas and sri vent (lil) atlas to the crudevent target - both atlases, big and lil, are required due to the variable nature of the NPH ventricle shape and size
# 3c. dilate the aligned atlases to ensure all lateral ventricle voxels are included in the following steps
# 4. create lateral ventricle
# 4a. create NPH- (big) and standard-sized (lil) vents by multiplying aligned and dilated atlases by narrowed supratentorial CSF
# 4b. create complete ventricle by combining big and lil vents
# 5. extract third ventricle in SRI space
# 6. smooth final ventricles to remove holes and clean edges
# 7. (optional, but recommended) subtract additional 3rd ventricle CSF
# 8. apply inverse transform to return CSF and ventricles back to native space
# 9. identify contiguous clusters in the lateral ventricle image and select the largest 10% of clusters based on cluster size
# 9a. select clusters of voxels with values > 0.1 (most inclusive, producing a slighly "bloated" lateral ventricle used for removing ventricle voxels from subarachnoid CSF)
# 9b. select clusters of voxels with values > 0.5 (may include some non-lateral ventricle voxels at edges)
# 10. create supratentorial subarachnoid and suprasylvian CSF
# 10a. clean edges of the supratentorial and SA CSF to remove volume averaging errors introduced during registration to return images to native space
# 10b. create complete ventricle (lateral + third)
# 10c. subtract complete ventricle (lateral + third) from supratentorial and SA CSF to extract extraventricular CSF voxels
# 11. (optional, but recommended for CA calculation) apply rigid body transformation to reorient vents to symmetric standard SRI space
# 12. (optional) append fslstats volume measures to a .txt file - NOTE: volumes saved can be easily modified in echo command

#The outputs of interest from this preprocessing script are:
# 1. _bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes (lateral ventricles)
# 2. _allvents_50_native (lateral ventricles + third ventricles)
# 3. _extravent_csf_native_trimmed (extraventricula CSF)
# 4. _SA_csf_native (suprasylvian subarachnoid CSF)


#Resources
# FSL Support https://fsl.fmrib.ox.ac.uk/fsl/docs/#/
# https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/image_processing_tips.html


#TO USE:
# 1. update image_dir with appropriate file directory path
# 2. open terminal window, execute 'bash SNImagingLab_STEP2_ct_segmentation_t24.sh'



#define file structure
##########################################################################################################
#parent directory where nifti images are stored
image_dir=#<<image_dir>>
#echo $image_dir

#location of the restore input image files to be analyzed
restore_dir=$image_dir/restore
#location of the working directory where intermediate and temporary image files are stored throughout the analysis pipeline
work_dir=$image_dir/work_t24
#location of the omat transformation matricies
omat_dir=$image_dir/omat_t24
#location of the bigvent and lilvent image files
interim_vent_dir=$image_dir/interim_vent_t24
#location of the output ventricle (lateral and lateral + 3rd) and suptent CSF image files
csf_dir=$image_dir/suptentcsf_t24
#location of the cluster analysis output files
cluster_dir=$image_dir/cluster_t24
#location of the extracted third ventricle output files and combined lateral + third ventricle output files
thirdvent_dir=$image_dir/thirdvent_t24
#location of the final vent image files in standard orientation with rigid body transformation
stdorient_dir=$image_dir/stdorient_t24

#echo $restore_dir
#echo $work_dir
#echo $csf_dir
#echo $cluster_dir


#define atlases for image alignment and ventricle masking
##########################################################################################################
atlas_dir=/mnt/Data/atlases
#echo $atlas_dir

##standard SRI24 brain atlas adjusted for CT HU values
sri_atlas=$atlas_dir/pbmap_HU.nii.gz

##standard SRI24 suptent compartment mask
suptent_mask=$atlas_dir/sri24/suptent.nii

##standard SRI24 suptent compartment mask slightly eroded by boxv kernel 1 x 1 x 1 to remove halo effect at edge of brain extraction
suptent_ero_mask=$atlas_dir/suptent_ero.nii.gz

##modified supratentorial mask to target ventricular csf
narrowed_csf_mask=$atlas_dir/narrowed_csfMASK

##"crudevent" mask used to create a target for registration with with big_atlas and lil_atlas
crudevent_atlas=$atlas_dir/crudeventMASK.nii.gz

##custom ventriculomegaly atlas created from patients with probable NPH useful for segmenting large ventricles
big_atlas=$atlas_dir/bigvent_atlas.nii.gz

##SRI24 atlas customized by KKing for segmenting standard-sized lateral ventricles in CT
lil_atlas=$atlas_dir/lilvent_atlas.nii.gz

##lagre third ventricle mask to REMOVE third ventricle contamination from lateral ventricle segmentation
third_vent_mask_2clean=$atlas_dir/thirdventMASK_2clean.nii.gz

##third ventricle to EXTRACT third ventricles
#custom made mask designed in Matlab to combine the third ventricle and lateral ventricles for a complete ventricle system
vent_system_3rdvent_mask=$atlas_dir/thirdventMASK_2add.nii.gz

##suprasylvain subarachnoid (SA) mask
#a mask created from the SRI TZO116 labeling atlas (tzo116plus.nii) trimmed to inlcude only suprasylvian subarachnoid labels 1-4, 7-8, 19-20, 23-24, 57-70
SA_mask=$atlas_dir/tzo_SA_mask.nii.gz



#initialize start time to append to volume .txt files
################################################################################
start_time=$(date '+%Y%m%d_%H%M%S');


################################################################################
#N says how many jobs (for loops) to run at a time.  This depends on available system cpu # and ram
# and amount of ram needed by each program being called
N=20

#for each iteration of the for loop, a file is found that meets the the criterion in the "find" command
#the criterion of the target file can be changed by changing the value in quotes ''
#for each file found, the commands inbetween () are applied
for filename in $(find $restore_dir -iname "*_restore_native.nii*"); do
(

#filename will have the full path, image file name and extension
#fname removes the path and extension and fname_short gives just the ID num

      #echo $filename #will include path, filename, and extension

      fname=$(basename $filename .nii.gz) #removes path and .nii.gz extension
      # echo $fname

      #fname_short=${fname:0:8} #extracts the 4-digit ID number and the 4 character image type indicator (bwct or shct), can be modified
      fname_short=$(echo ${fname} | cut -d '_' -f 1) #extracts the ID and image type indicator to the left of the first '_'
      echo $fname_short


#step 1
#use fsl's flirt to align the bias field corrected "_restore" brain image to the SRI24 standard brain
#-omat option saves a transformation matrix with the specified filename that can be used later to apply a reverse transformation back to native space
##################################################################################################
flirt -in ${restore_dir}/${fname_short}_restore_native -ref $sri_atlas -out ${work_dir}/${fname_short}_restore_sri -omat ${omat_dir}/${fname_short}_restore_aligntosri -interp trilinear
#invert -omat transformation matrix to create new matrix that can be applied to return an image back to native space
convert_xfm -omat ${omat_dir}/${fname_short}_restore_aligntonative -inverse ${omat_dir}/${fname_short}_restore_aligntosri


#step 2
#create suptent csf
#step 2a
#create suptent csf for calculating CSF volume and hence SA CSF for ratio
#The _suptent brain is multiplied by the SRI suptent mask previously eroded with spatial filtering (kernel size of 1 x 1 x 1).
#This erosion is intended to remove some of the halo artifact at the edges of the mask due to volume averaging
#NOTE: when converted back to native space, the _suptent_ero1_csf_native will be multiplied by the whole brain _restore_native_csf to
#remove any excess voxels at the edges erroneously ID'd as CSF due to volume averaging into the 0-20 range.
##################################################################################################
fslmaths ${work_dir}/${fname_short}_restore_sri -mul $suptent_ero_mask ${work_dir}/${fname_short}_suptent_ero1

#step 2b
#extracte CSF using thresholding
#-uthr <n> zeros anything above n (voxels <20 are likely csf)
#-bin binarizes so output voxel values 0 or 1
##################################################################################################
fslmaths ${work_dir}/${fname_short}_suptent_ero1 -uthr 24 -bin ${work_dir}/${fname_short}_suptent_ero1_csf_sri

#step 2c
#create narrowed CSF mask targeting the lateral ventricles by multiplying suptent_csf with a custom-made mask created based on NPH and HA patient data.
#this targeted csf is later multiplied by the dilated vent masks to create bigvent and lilvent
##################################################################################################
fslmaths ${work_dir}/${fname_short}_suptent_ero1_csf_sri -mul $narrowed_csf_mask ${work_dir}/${fname_short}_narrowed_csf_sri

#step 2d
#create supratentorial subarachnoid CSF by multiplying suptent_csf with a mask created from the SRI tzo116plus.nii modified to include only the superior subarachnoid regions of the brain
##################################################################################################
fslmaths ${work_dir}/${fname_short}_suptent_ero1_csf_sri -mul $SA_mask ${work_dir}/${fname_short}_SA_csf_sri


#step 3
#create aligned ventricle atlases
#3a
#create target crudevent for alignment
#initial "crude" identification of csf around the central aspect of the ventricle by multiplying by a modified and oversized bigvent atlas
#this new "crude" venticle will be used as a target for flirt alignment
##################################################################################################
fslmaths ${work_dir}/${fname_short}_suptent_ero1_csf_sri -mul $crudevent_atlas ${work_dir}/${fname_short}_suptent_crudevent

#3b
#align bigvent and lilvent atlases to target crudevent
#use fsl's flirt function to register ventricle atlases to the crude ventricle
##################################################################################################
flirt -in $big_atlas -ref ${work_dir}/${fname_short}_suptent_crudevent -out ${work_dir}/${fname_short}_bigvent -omat ${omat_dir}/${fname_short}_bigvent -paddingsize 0.0 -interp trilinear
flirt -in $lil_atlas -ref ${work_dir}/${fname_short}_suptent_crudevent -out ${work_dir}/${fname_short}_lilvent -omat ${omat_dir}/${fname_short}_lilvent -paddingsize 0.0 -interp trilinear

#3c
#dilate ventricles to create final vent masks
#dilate vents to capture entire lateral ventricles
#dilate with spatial filtering
# -dilF    : Maximum filtering of all voxels
# -kernel boxv   <size>     : all voxels in a cube of width <size> voxels centered on target voxel, CAUTION: size should be an odd number
#ALTERNATIVE OPTION: can binarize the vent output by adding the "-bin" option (like a true mask)
##################################################################################################
fslmaths ${work_dir}/${fname_short}_bigvent -kernel boxv 11 -dilF -bin ${work_dir}/${fname_short}_bigvent_dilF11
fslmaths ${work_dir}/${fname_short}_lilvent -kernel boxv 11 -dilF -bin ${work_dir}/${fname_short}_lilvent_dilF11


#step 4
#create ventricles
#step 4a.
#create 2 ventricle variations, a large NPH-shaped ventricle and a smaller standard-shaped ventricle
#multiply aligned and dilated vent atlases by smaller fov csf to create more complete vent without SA contamination
##################################################################################################
fslmaths ${work_dir}/${fname_short}_bigvent_dilF11 -mul ${work_dir}/${fname_short}_narrowed_csf_sri ${interim_vent_dir}/${fname_short}_bigvent_dilF11_ero11_sri
fslmaths ${work_dir}/${fname_short}_lilvent_dilF11 -mul ${work_dir}/${fname_short}_narrowed_csf_sri ${interim_vent_dir}/${fname_short}_lilvent_dilF11_ero11_sri

#step 4b.
#combine bigvent and lilvent to create a complete ventricle
#lilvent appears to include more of the posterior lateral horns of control patients
#while bigvent captures more of the central aspect of the lateral ventricles, especially the enlarged ventricles typical of NPH
#values of summed output image range from 0 -> 2 with voxels of overlap having max value of 2.
#"_sri" added to end of output filename to indicate vent in standard sri space
##################################################################################################
fslmaths ${interim_vent_dir}/${fname_short}_bigvent_dilF11_ero11_sri -add ${interim_vent_dir}/${fname_short}_lilvent_dilF11_ero11_sri ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_sri


#step 5
#extract the third ventricle to create a complete ventricular system (lateral + 3rd)
#multiply by entire suptent csf, not the narrowed csf
#this third ventricle will be added to the lateral ventricles after the largest clusters are selected
##################################################################################################
fslmaths ${work_dir}/${fname_short}_suptent_ero1_csf_sri -mul $vent_system_3rdvent_mask ${thirdvent_dir}/${fname_short}_thirdvent_sri


#step 6
#smooth and threshold
#smoothing removes holes in vents (in future, could try FSL's -fillh command to fill holes in masks)
#output image range for bigvent and lilvent and thirdvent is 0 - 1
#output image range for bignlilvent is 0 - 2
#thresholding is necessary to remove ballooned low intensity edges as a result of smoothing
##################################################################################################
fslmaths ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_sri -s 1 -thr 0.5 ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sri
fslmaths ${thirdvent_dir}/${fname_short}_thirdvent_sri -s 1 -thr 0.25 ${thirdvent_dir}/${fname_short}_thirdvent_s1_sri


#step 7 (OPTIONAL, but recommended)
#remove additional third ventricle csf from final vent (may remove some lateral vent from extremely large NPH vents)
#third_vent_mask_2clean intensity is 0 or 2 to remove 3rd vent from bignlilvent with range 0 - 2
##################################################################################################
fslmaths ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sri -sub $third_vent_mask_2clean -thr 0 ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_sri


#step 8
#use inverted transformation matrix to transform suptent_csf and vent images back to native space
#the reference image for the flirt command is the _restore_native brain image and is solely used to define the size of flirt's output volume
#*_restore_aligntosri is the matrix that will transform an image to sri standard space when applied with the flirt command
#*_restore_aligntonative is the matrix that will transform an image to native space when applied with the flirt command
################################################################################
flirt -in ${work_dir}/${fname_short}_suptent_ero1_csf_sri -applyxfm -init ${omat_dir}/${fname_short}_restore_aligntonative -out ${csf_dir}/${fname_short}_suptent_ero1_csf_native -paddingsize 0.0 -interp trilinear -ref ${restore_dir}/${fname_short}_restore_native
flirt -in ${work_dir}/${fname_short}_SA_csf_sri -applyxfm -init ${omat_dir}/${fname_short}_restore_aligntonative -out ${csf_dir}/${fname_short}_SA_csf_native -paddingsize 0.0 -interp trilinear -ref ${restore_dir}/${fname_short}_restore_native
#flirt -in ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sri -applyxfm -init ${omat_dir}/${fname_short}_restore_aligntonative -out ${interim_vent_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_native -paddingsize 0.0 -interp trilinear -ref ${restore_dir}/${fname_short}_restore_native
flirt -in ${work_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_sri -applyxfm -init ${omat_dir}/${fname_short}_restore_aligntonative -out ${interim_vent_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native -paddingsize 0.0 -interp trilinear -ref ${restore_dir}/${fname_short}_restore_native
flirt -in ${thirdvent_dir}/${fname_short}_thirdvent_s1_sri -applyxfm -init ${omat_dir}/${fname_short}_restore_aligntonative -out ${thirdvent_dir}/${fname_short}_thirdvent_s1_native -paddingsize 0.0 -interp trilinear -ref ${restore_dir}/${fname_short}_restore_native


#step 9
#fsl cluster analysis to select largest contiguous clusters in vent image
#NOTE: threshold values in cluster analysis can be modified to optimize edges of segmented ventricles
#step 9a - cluster threshold 0.10 (includes all possible CSF voxels in region of ventricles to create a slightly bloated lateral ventricle that will be used to remove all vent CSF voxels when creating SA CSF)
#range of input _bignlilvent_dilF11_ero11_s1_sub3rdL_native is 0 - 2
#final outputs: _maxCLUSTERsize is the single largest contiguous cluster based on cluster size.
#               _largestCLUSTERsizes is a combination of the top larges clusters with sizes 10% - 100%
#NOTE: the largestCLUSTERsizes can be modified to include a different range of cluster sizes by changing the cutoff value below
################################################################################
#find clusters for native bignlilvent with third vent mask removed (for lateral vents ONLY)
cluster -i ${interim_vent_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native -t .10 --connectivity=6 --osize=${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_CLUSTERsize_t10_c6 > ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10CLUSTERinfo.txt
size_thresh_max10_sub3=$(awk 'NR == 2 {print $2}' ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10CLUSTERinfo.txt);
cutoff=0.1; #apply a percent cutoff to select all clusters with size greater than or equal to a defined percentage of the max cluster size (tried 10%-30%)
size_thresh_cutoff10_sub3=$(echo "$size_thresh_max10_sub3 * $cutoff;" | bc);
echo "$fname_short size_thresh_max10_sub3 = $size_thresh_max10_sub3; size_thresh_cutoff10_sub3 $cutoff = $size_thresh_cutoff10_sub3"

#apply thresholding using fslmaths to select largest clusters based on size
#-thr = zero anything below the number
#-uthr = zero anything above the number
#fslmaths -dt int ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_CLUSTERsize_t10_c6 -thr ${size_thresh_max10_sub3} -uthr ${size_thresh_max10_sub3} -bin ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10maxCLUSTERsize #-odt char
fslmaths -dt int ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_CLUSTERsize_t10_c6 -thr ${size_thresh_cutoff10_sub3} -uthr ${size_thresh_max10_sub3} -bin ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10largestCLUSTERsizes #-odt char


#step 9b. - cluster threshold 0.5 (include some volume averaged edges for a slightly inaccurate bloat)
#range of input _bignlilvent_dilF11_ero11_s1_sub3rdL_native is 0 - 2
#final outputs: _maxCLUSTERsize is the single largest contiguous cluster based on cluster size.
#               _largestCLUSTERsizes is a combination of the top larges clusters with sizes 10% - 100%
#NOTE: the largestCLUSTERsizes can be modified to include a different range of cluster sizes by changing the cutoff value below
################################################################################
#find clusters for native bignlilvent with third vent mask removed (for lateral vents ONLY)
cluster -i ${interim_vent_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native -t .5 --connectivity=6 --osize=${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_CLUSTERsize_t50_c6 > ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50CLUSTERinfo.txt
size_thresh_max50_sub3=$(awk 'NR == 2 {print $2}' ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50CLUSTERinfo.txt);
cutoff=0.1; #apply a percent cutoff to select all clusters with size greater than or equal to a defined percentage of the max cluster size (tried 10%-30%)
size_thresh_cutoff50_sub3=$(echo "$size_thresh_max50_sub3 * $cutoff;" | bc);
echo "$fname_short size_thresh_max50_sub3 = $size_thresh_max50_sub3; size_thresh_cutoff50_sub3 $cutoff = $size_thresh_cutoff50_sub3"

#apply thresholding using fslmaths to select largest clusters based on size
#-thr = zero anything below the number
#-uthr = zero anything above the number
#fslmaths -dt int ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_CLUSTERsize_t50_c6 -thr ${size_thresh_max50_sub3} -uthr ${size_thresh_max50_sub3} -bin ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50maxCLUSTERsize #-odt char
fslmaths -dt int ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_CLUSTERsize_t50_c6 -thr ${size_thresh_cutoff50_sub3} -uthr ${size_thresh_max50_sub3} -bin ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes #-odt char



##step 10
#create supratentorial subarachnoid csf
#"extravent" refers to all supratentorial extraventricular CSF outside of the ventricles
#"SA" refers to suprasylvian supratentorial CSF (optional)
#step 10a.
#NOTE: need to remove "halo effect" voxels at the edge of suptent_ero1_csf_native added during registration due to volume averaging.
#These excess CSF voxels are removed, or "trimmed", by multiplying suptent_ero1_csf_native by the whole brain CSF image created in native space without registration (_restore_native_csf)
##################################################################################################
#Trim:
fslmaths ${csf_dir}/${fname_short}_suptent_ero1_csf_native -mul ${restore_dir}/${fname_short}_restore_native_csf_t24 -bin ${csf_dir}/${fname_short}_suptent_ero1_csf_native_trimmed
fslmaths ${csf_dir}/${fname_short}_SA_csf_native -mul ${restore_dir}/${fname_short}_restore_native_csf_t24 -bin ${csf_dir}/${fname_short}_SA_csf_native_trimmed

#step 10b.
#create combined lateral and third ventricles "mask"
#NOTE: _10largestCLUSTERsizes includes the most CSF voxels in the ventricle region which will ensure all ventricular CSF voxels are removed when subtracting in step 10c to create true extraventricular SA CSF.
#NOTE: _50largestCLUSTERsizes was combined with thirdvent for to calculate SA CSF Vol (SA CSF = suptent_ero1_csf_native - allvents_50_native) for Jacob Knittle's manuscript.
##################################################################################################
fslmaths ${thirdvent_dir}/${fname_short}_thirdvent_s1_native -add ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10largestCLUSTERsizes -bin ${thirdvent_dir}/${fname_short}_allvents_native
fslmaths ${thirdvent_dir}/${fname_short}_thirdvent_s1_native -add ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes -bin ${thirdvent_dir}/${fname_short}_allvents_50_native

#step 10c.
#subtract ventricles from supratentorial CSF so only extraventricular subarachnoid CSF remains
##################################################################################################
fslmaths ${csf_dir}/${fname_short}_suptent_ero1_csf_native -sub ${thirdvent_dir}/${fname_short}_allvents_native -thr 0 ${csf_dir}/${fname_short}_extravent_csf_native
fslmaths ${csf_dir}/${fname_short}_SA_csf_native -sub ${thirdvent_dir}/${fname_short}_allvents_native -thr 0 ${csf_dir}/${fname_short}_SA_csf_native
#Trim:
fslmaths ${csf_dir}/${fname_short}_suptent_ero1_csf_native_trimmed -sub ${thirdvent_dir}/${fname_short}_allvents_native -bin ${csf_dir}/${fname_short}_extravent_csf_native_trimmed
fslmaths ${csf_dir}/${fname_short}_SA_csf_native_trimmed -sub ${thirdvent_dir}/${fname_short}_allvents_native -bin ${csf_dir}/${fname_short}_SA_csf_native_trimmed



#step 11 (OPTIONAL)
#transform _restore_native and lateral ventricles to symmetric, standard SRI orientation with rigid body transoformation
#rigid body transformation applies only translation and rotation applied, NOT skew
#two different methods options (Method 1 is preferred):
#Method 1. get transformation matrix from aligning _restore_native brain to sri with rigid body transformation; apply transformation matrix to ventricles (PREFERRED METHOD)
#NOTE: this step is important for automated CA analysis
################################################################################################
#Method 1. (PREFERRED METHOD)
#register _restore_native to sri standard space with 6 DOF rigid body transformation
flirt -in ${restore_dir}/${fname_short}_restore_native -ref $sri_atlas -out ${stdorient_dir}/${fname_short}_restore_native_6DOF -omat ${omat_dir}/${fname_short}_restore_native_6DOFtosriatlas.mat -dof 6 -interp trilinear
#apply transformation matrix
flirt -in ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10largestCLUSTERsizes -applyxfm -init ${omat_dir}/${fname_short}_restore_native_6DOFtosriatlas.mat -out ${stdorient_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_10largestCLUSTERsizes_6DOFapplyomat -paddingsize 0.0 -interp trilinear -ref ${stdorient_dir}/${fname_short}_restore_native_6DOF
flirt -in ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes -applyxfm -init ${omat_dir}/${fname_short}_restore_native_6DOFtosriatlas.mat -out ${stdorient_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes_6DOFapplyomat -paddingsize 0.0 -interp trilinear -ref ${stdorient_dir}/${fname_short}_restore_native_6DOF



# #step 12 (OPTIONAL)
# #create and append stats data to saved text file
# ################################################################################################
# echo "adding $fname_short to Volumes_${start_time}.txt"
# # echo "${fname_short:0:4} ${fname_short} ${fname_short}_restore_native: $(fslstats ${restore_dir}/${fname_short}_restore_native -V -M) ${fname_short}_restore_native_csf: $(fslstats ${restore_dir}/${fname_short}_restore_native_csf -V -M) ${fname_short}_suptent_ero1_csf_native: $(fslstats ${csf_dir}/${fname_short}_suptent_ero1_csf_native -V -M) ${fname_short}_suptent_ero1_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_suptent_ero1_csf_native_trimmed -V -M) ${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes: $(fslstats ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes -V -M) ${fname_short}_allvents_50_native: $(fslstats ${thirdvent_dir}/${fname_short}_allvents_50_native -V -M) ${fname_short}_extravent_csf_native: $(fslstats ${csf_dir}/${fname_short}_extravent_csf_native -V -M) ${fname_short}_extravent_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_extravent_csf_native_trimmed -V -M)" >> ${image_dir}/Volumes_${start_time}.txt



) &

    # allow to execute up to $N jobs in parallel
    if [[ $(jobs -r -p | wc -l) -ge $N ]]; then
        # now there are $N jobs already running, -n option waits for any job
        # to finish first so there is a place to start next one.
        wait -n
    fi

done

# no more jobs to be started but wait for pending jobs
# (all need to be finished)
wait

echo "all done"

#capture end time and report overall time
################################################################################################
stop_time=$(date '+%Y%m%d_%H%M%S');
mid_time=$(echo "${stop_time:9:6} - ${start_time:9:6};" | bc)

echo "all done"
printf "Total time (HHMMSS): %06d\n" $mid_time
