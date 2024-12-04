#!/bin/bash


#This script applies initial preprocessing techniques to CT images:
# 1. reorient to standard orientation
# 2. reslice to create isotropic 1mm x 1mm x 1mm voxel images
# 3. remove neck tissue
# 4. smooth
# 5. remove bone and fat with thresholding (threshold to 120HU)
# 6. remove skull (brain extraction with FSL's BET and masking)
# 7. apply bias field correction (with FSL's FAST)
# 8. apply thresholding to extract CSF voxels (0 - 20HU AND 0 - 24HU)

#The outputs of interest from this preprocessing script are:
# 1. _restore_native (bias field corrected brain using most complete brain extraction mask from -thr 60 brain)
# 2. _restore_native_csf (CSF voxels 0 - 20HU)
# 3. _restore_native_csf_t24 (CSF voxels 0 - 24HU)


#Resources
# FSL Support https://fsl.fmrib.ox.ac.uk/fsl/docs/#/
# https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/image_processing_tips.html

#TO USE:
# 1. update image_dir with appropriate file directory path
# 2. open terminal window, execute 'bash SNImagingLab_STEP1_ct_preprocess.sh'

#define file structure
##########################################################################################################
#parent directory where nifti images are stored
image_dir=#<<image_dir>>
#echo $image_dir

#location of the input image files to be analyzed
input_dir=$image_dir/raw_input
#location of the working directory where intermediate and temporary image files
#are stored throughout the analysis pipeline
work_dir=$image_dir/work
#location of the smooth image files
smooth_dir=$image_dir/smooth
#location of the output image files
output_dir=$image_dir/restore


echo $input_dir
echo $work_dir
echo $output_dir



#initialize start time to calculate overall processing time
################################################################################
start_time=$(date '+%Y%m%d_%H%M%S');



################################################################################
#N says how many jobs (for loops) to run at a time.  This depends on available system cpu # and ram
# and amount of ram needed by each program being called
N=20

#for each iteration of the for loop, a file is found that meets the the criterion in the "find" command
#the criterion of the target file can be changed by changing the value in quotes ''
#for each file found, the commands inbetween () are applied
for filename in $(find $input_dir -iname '*bwct*.nii.gz'); do
(

#filename will have the full path, image file name and extension
#fname removes the path and extension and fname_short gives just the ID num

      #echo $filename #will include path, filename, and extension

      fname=$(basename $filename .nii.gz) #removes path and .nii.gz extension
      # echo $fname

      idnum=${fname:0:4} #extracts 4-digit ID number
      # echo $idnum

      #below if statement determines the image type, BW or ST, and creates variable image_type to append to output filename
      #NOTE: raw image filenames end with a nunmber indicating the Series Number from the scan
      #typically...
      #Series Number = 2 - "WAND HD ST"
      #Series Number = 3 - "WAND HEAD BW"
      #Series Number = 4 - "HD ST" for thick slice ct
      #this filename feature may be useful...
      if [[ ${fname:4:4} == 'bwct' ]]  || [[ ${fname:4:4} == 'hact' ]]
      then
        image_type=bwct #image_type set to BW for bone windowing
      elif [[ ${fname:4:4} == 'preo' ]]
      then
        image_type=stct #image_type set to ST for soft tissue windowing
      elif [[ ${fname:4:4} == '_thi' ]]
      then
        image_type=thickstct #image_type set to THICK ST for soft tissue windowing with 5mm thickness
      elif [[ ${fname:4:4} == 'thic' ]]
      then
        image_type=${fname:4:9} #image_type set to THICK for soft tissue or bone windowing with 5mm thickness
      else
        image_type='' #default case created in the event there is no BW or ST indicator match
      fi
      #echo $image_type
      fname_short=${idnum}${image_type}
      echo $fname_short


#Step 1
#Reorient the image to standard orientation
##########################################################################################################
fslreorient2std ${filename} ${work_dir}/${fname_short}


#Step 2
#create isotropic/isovolumetric images saved in working directory.
#iso.sh is from Dianne Patterson dkp@email.arizona.edu https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/image_processing_tips.html
##########################################################################################################
iso.sh ${work_dir}/${fname_short} 1 #output is named ${idnum}${image_type}_1mm for new file with 1mm x 1mm x 1mm voxel size


#Step 3
#remove neck included in WAND images
#################################################################################################################
robustfov -i ${work_dir}/${fname_short}_1mm -r ${work_dir}/${fname_short}_noneck

#Step 4
#smooth the image
#the -s option defines the size in mm of the sigma smoothing kernel for mean filtering
#################################################################################################################
fslmaths  ${work_dir}/${fname_short}_noneck -s 1  ${smooth_dir}/${fname_short}_smooth

#Step 5
#remove bone and fat
#image looks more like T1, values of 80 or 100 for upper threshold will leave some artifactual high intensity
#due to volume averaging with calcium/ bone.
#a threshold of 60 removes this but also removes some needed structures due to hyperintensities.
#a threshold of 120 seems to include all structures and eroding the final mask seems to reliably remove most of the
#artifactual high intensity at edges
#the -thr <n> option zeros anything below n
#the -uthr <n> option zeros anything abouve n
#################################################################################################################
fslmaths  ${smooth_dir}/${fname_short}_smooth -kernel gauss 5 -thr 0 -uthr 120  ${work_dir}/${fname_short}_thr #why add "-kernel gauss 5" to this command?? Is it applied without a filter option??

#Step 6
#skull strip, trial and error to find value for -f and -g.
#-f <f> is frantional intensity threshold (0-1); default=0.5; smaller values give larger brain outline estimates
#-g <g> vertical gradient in fractional intensity threshold (-1-1); default=0; positive values give larger brain outline at bottom, smaller at top
#about 1/20 fail bet and have a geometric shaped hole.  luckily a different 5% fail for different f values.
#We therefore run it twice and then add the two together with fslmaths to create a combo mask that will hopefully fail less often, about 1/400..
#FSL's BET brain mask -m option outputs a complete binary mask. this mask should not have any holes, but -fillh is also used to fill any remaining small holes
#NOTE: BET's brain masks over estimate the brain tissue and include high intensity voxels at the edge of the brain extraction.
#an erosion step is applied to remove the artifact at the edges
#NOTE: a more complicated masking method with a slightly better brain mask contour is used in EF_KK_STEP1_ct_preprocess_dec2023_completBET.sh
#################################################################################################################
bet ${work_dir}/${fname_short}_thr  ${work_dir}/${fname_short}_f1 -f 0.1 -g -0.3 -m
bet ${work_dir}/${fname_short}_thr  ${work_dir}/${fname_short}_f2 -f 0.2 -g -0.3 -m
fslmaths ${work_dir}/${fname_short}_f1_mask -add ${work_dir}/${fname_short}_f2_mask -fillh ${work_dir}/${fname_short}_f1f2_mask #-fillh ensures all small holes are filled
fslmaths ${work_dir}/${fname_short}_f1f2_mask -kernel boxv 5 -ero ${work_dir}/${fname_short}_f1f2_mask_ero5
fslmaths ${work_dir}/${fname_short}_f1f2_mask_ero5 -bin -mul ${smooth_dir}/${fname_short}_smooth ${work_dir}/${fname_short}_bet #NOTE: the range of intensities for this output differs from original _bet ranges



#Step 7
#fsl fast segmentation into brain and csf components
#the primary output of interest is the bias field corrected "_restore" brain
#fast will create its own suffix for its varied output files (_restore, _pve_#, etc.).
#fsl command line structure: fast [options] <input image file>
#[options]:
#-t <n> sets image type (T1, T2, PD)
#-n <n> specifies number of tissue classes to estimate (if n=3, partial volume estimate: pve_0 = CSF, pve_1 = GM, pve_2 = WM and seg_0 = CSF, seg_1 = GM, seg_2 = WM)
#NOTE: n = 2 may work better for CTs
#-H <v> MRF beta value for segmentation phase (larger value produces smoother segmentation)
#-I <n> number of loop iterations during initial bias field removal phase
#-l <m> bias field smoothing FWHM in mm
#-B output restored image (_restore)
#-b output estimated bias field
#-o basename for output files
################################################################################################
fast -t 1 -n 2 -H 0.1 -I 4 -l 20.0 -g -B -b -o ${work_dir}/${fname_short}_native ${work_dir}/${fname_short}_bet
#rename for use in Step 2 segmentation script
immv ${work_dir}/${fname_short}_native_restore ${output_dir}/${fname_short}_restore_native
fslmaths ${output_dir}/${fname_short}_restore_native -uthr 20 -bin ${output_dir}/${fname_short}_restore_native_csf
fslmaths ${output_dir}/${fname_short}_restore_native -uthr 24 -bin ${output_dir}/${fname_short}_restore_native_csf_t24
fslmaths ${work_dir}/${fname_short}_f1f2_mask_ero5 -bin ${work_dir}/${fname_short}_icv_native #create "ICV" image from brain mask (should already be binarized, but applying -bin again for assurance)


#clean up and delete unnecessary files and rename _native_restore to _restore_native so it matches _restore_sri filename in ct_sri_preprocessing script
################################################################################################
#remove unnecessary files
imrm ${work_dir}/${fname_short}
imrm ${work_dir}/${fname_short}_noneck ${work_dir}/${fname_short}_1mm
imrm ${work_dir}/${fname_short}_thr
imrm ${work_dir}/${fname_short}_f1 ${work_dir}/${fname_short}_f2
imrm ${work_dir}/${fname_short}_f1_mask ${work_dir}/${fname_short}_f2_mask
imrm ${work_dir}/${fname_short}_f1f2 ${work_dir}/${fname_short}_f1f2_mask
imrm ${work_dir}/${fname_short}_f1f2_mask_ero5 ${work_dir}/${fname_short}_bet
imrm ${work_dir}/${fname_short}_native_pve_0 ${work_dir}/${fname_short}_native_pve_1
imrm ${work_dir}/${fname_short}_native_pveseg ${work_dir}/${fname_short}_native_mixeltype
imrm ${work_dir}/${fname_short}_native_bias ${work_dir}/${fname_short}_native_seg


    ) &

    # allow to execute up to $N jobs in parallel
    if [[ $(jobs -r -p | wc -l) -ge $N ]]; then
        # now there are $N jobs already running, so wait here for any job
        # to be finished so there is a place to start next one.
        wait -n
    fi

done

# no more jobs to be started but wait for pending jobs
# (all need to be finished)
wait



#capture end time and report overall time
################################################################################################
stop_time=$(date '+%Y%m%d_%H%M%S');
mid_time=$(echo "${stop_time:9:6} - ${start_time:9:6};" | bc)

echo "all done"
printf "Total time (HHMMSS): %06d\n" $mid_time
