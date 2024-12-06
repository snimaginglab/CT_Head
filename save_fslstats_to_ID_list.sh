#!/bin/bash

#This script runs fslstats for a select list of subject IDs read from a csv file:
#This particular script is set to output the fslstats for the _restore_native, _suptent_ero1_csf_native,
#and _bignlilvent_dilF11_ero11_s1_native_maxCLUSTERsize image files and save the output in a .txt file
#NOTE: .csv file containing ID list must be saved in image_dir/ID_lists, contain "ID" in the filename, and contain
#the following contents as the first 4 columns: {ID}, {Group}, {Gender}, {Age}

#TO USE:
# 1. Update image_dir
# 2. Update IDlist_dir and ID_list search criteria (ie. "*ID*.csv")
# 3. Update output_txt_dir where output data .txt file will be saved
# 4. Update output_txt_filename to be the desired filename of the output .txt file
# 5. open terminal window, execute 'bash SNImagingLab_save_fslstats_to_IDlist.sh'


#define file structure
##########################################################################################################
#parent directory where nifti images are stored
image_dir=#<<unage_dir>>

#location of the restore brain extraction image files
restore_dir=$image_dir/restore
#location of the restore brain extraction image files
work_dir=$image_dir/work
#location of the SA and extraventricular CSF image using CSF with threshold cutoffs of 0 - 20 HU
csf_dir=$image_dir/suptentcsf
#location of the SA and extraventricular CSF image using CSF with threshold cutoffs of 0 - 24 HU
csf_t24_dir=$image_dir/suptentcsf_t24
#location of the lateral ventricle image files
cluster_dir=$image_dir/cluster
#location of the complete ventricular system (lateral + 3rd vents) image files
thirdvent_dir=$image_dir/thirdvent


#initialize start time to append to volume .txt files
################################################################################
start_time=$(date '+%Y%m%d_%H%M%S');

#find .csv file containing list of IDs to be processed
#NOTE: ID_list MUST have the format {ID},{Group},{Gender},{Age} for the first 4 columns
################################################################################
IDlist_dir=$image_dir/ID_lists #modify to specify directory containing the desired ID list
ID_list=$(basename $(find $IDlist_dir -iname  "*ID*.csv")); #modify to specify .csf filename containing the desired ID list
ID_filename=$(basename $ID_list .csv)
echo "Reading ID numbers from: $ID_list"

output_txt_dir=#<<output_txt_dir>>
output_txt_filename=#<<output_txt_filename>>


#while loop
#for each interation of the while loop, the subsequent line of the .csv file is
#read and the commands in () are applied.
#In this case, the commands run fslstats and output the specified volumes to a .txt files
################################################################################
while IFS="," read -r ID_num Group Gender Age; do
(
      #create fname_short
      fname_short=${ID_num}bwct
      #fname_short=${ID_num}thickbwct
      #echo $fname_short

#create and append stats data to saved text file
################################################################################################
  echo "adding volumes for $fname_short to ${output_txt_filename}_${start_time}.txt"
  #echo "${ID_num} ${Group} ${Gender} ${Age} ${fname_short} ${fname_short}_restore_native: $(fslstats ${restore_dir}/${fname_short}_restore_native -V -M) ${fname_short}_icv_native: $(fslstats ${work_dir}/${fname_short}_icv_native -V -M) ${fname_short}_restore_native_csf: $(fslstats ${restore_dir}/${fname_short}_restore_native_csf -V -M) ${fname_short}_suptent_ero1_csf_native: $(fslstats ${csf_dir}/${fname_short}_suptent_ero1_csf_native -V -M) ${fname_short}_suptent_ero1_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_suptent_ero1_csf_native_trimmed -V -M) ${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes: $(fslstats ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes -V -M) ${fname_short}_allvents_native: $(fslstats ${thirdvent_dir}/${fname_short}_allvents_native -V -M) ${fname_short}_allvents_50_native: $(fslstats ${thirdvent_dir}/${fname_short}_allvents_50_native -V -M) ${fname_short}_SA_csf_native: $(fslstats ${csf_dir}/${fname_short}_SA_csf_native -V -M) ${fname_short}_SA_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_SA_csf_native_trimmed -V -M) ${fname_short}_extravent_csf_native: $(fslstats ${csf_dir}/${fname_short}_extravent_csf_native -V -M) ${fname_short}_extravent_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_extravent_csf_native_trimmed -V -M) ${fname_short}_extravent_csf_native-t24: $(fslstats ${csf_t24_dir}/${fname_short}_extravent_csf_native -V -M) ${fname_short}_extravent_csf_native_trimmed-t24: $(fslstats ${csf_t24_dir}/${fname_short}_extravent_csf_native_trimmed -V -M)" >> ${output_txt_dir}/${output_txt_filename}_${start_time}.txt
  echo "${ID_num} ${Group} ${Gender} ${Age} ${fname_short} ${fname_short}_restore_native: $(fslstats ${restore_dir}/${fname_short}_restore_native -V -M) ${fname_short}_icv_native: $(fslstats ${work_dir}/${fname_short}_icv_native -V -M) ${fname_short}_restore_native_csf: $(fslstats ${restore_dir}/${fname_short}_restore_native_csf -V -M) ${fname_short}_restore_native_csf_t24: $(fslstats ${restore_dir}/${fname_short}_restore_native_csf_t24 -V -M) ${fname_short}_suptent_ero1_csf_native: $(fslstats ${csf_dir}/${fname_short}_suptent_ero1_csf_native -V -M) ${fname_short}_suptent_ero1_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_suptent_ero1_csf_native_trimmed -V -M) ${fname_short}_suptent_ero1_csf_native-t24: $(fslstats ${csf_t24_dir}/${fname_short}_suptent_ero1_csf_native -V -M) ${fname_short}_suptent_ero1_csf_native_trimmed-t24: $(fslstats ${csf_t24_dir}/${fname_short}_suptent_ero1_csf_native_trimmed -V -M) ${fname_short}_allvents_50_native: $(fslstats ${thirdvent_dir}/${fname_short}_allvents_50_native -V -M) ${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes: $(fslstats ${cluster_dir}/${fname_short}_bignlilvent_dilF11_ero11_s1_sub3rd_native_50largestCLUSTERsizes -V -M) ${fname_short}_SA_csf_native: $(fslstats ${csf_dir}/${fname_short}_SA_csf_native -V -M) ${fname_short}_SA_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_SA_csf_native_trimmed -V -M) ${fname_short}_SA_csf_native-t24: $(fslstats ${csf_t24_dir}/${fname_short}_SA_csf_native -V -M) ${fname_short}_SA_csf_native_trimmed-t24: $(fslstats ${csf_t24_dir}/${fname_short}_SA_csf_native_trimmed -V -M) ${fname_short}_extravent_csf_native: $(fslstats ${csf_dir}/${fname_short}_extravent_csf_native -V -M) ${fname_short}_extravent_csf_native_trimmed: $(fslstats ${csf_dir}/${fname_short}_extravent_csf_native_trimmed -V -M) ${fname_short}_extravent_csf_native-t24: $(fslstats ${csf_t24_dir}/${fname_short}_extravent_csf_native -V -M) ${fname_short}_extravent_csf_native_trimmed-t24: $(fslstats ${csf_t24_dir}/${fname_short}_extravent_csf_native_trimmed -V -M)" >> ${output_txt_dir}/${output_txt_filename}_${start_time}.txt


#end of while loop reading list of ID numbers in csv file
)
done < <(tail -n +2 ${IDlist_dir}/$ID_list)

# no more jobs to be started but wait for pending jobs
# (all need to be finished)
wait

#capture end time and report overall time
################################################################################################
stop_time=$(date '+%Y%m%d_%H%M%S');
mid_time=$(echo "${stop_time:9:6} - ${start_time:9:6};" | bc)

echo "all done"
printf "Total time (HHMMSS): %06d\n" $mid_time
