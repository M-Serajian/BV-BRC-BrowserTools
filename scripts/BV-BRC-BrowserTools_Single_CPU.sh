#!/bin/bash
date;hostname
echo "The directory in which Patric_genome_downloader was run is: "
echo $(pwd)
# This function will change the working directory to the directory in which 
# Patric_genome_downloader project exists to be sure utilities are loaded correctly!

aanpasbaar_runing() {
  local initial_working_directory=$1
  local Patric_genome_downloader_directory=$2
  if [ "$initial_working_directory" != "$Patric_genome_downloader_directory" ]; then
      # Change the working directory to the target directory
      cd "$Patric_genome_downloader_directory" || { echo -e "\e[31mError occurred changing" \
      "the working directory to directory of Patric_genome_downloader, program aborted!\e[0m"; exit 2; }
  fi
}


current_directory=$(pwd)
echo "the current working directory is :$current_directory"
#Processing args

# Processing arguments

# Default values for optional arguments
cpus=1



# loading the utilities
source $current_directory/utils/directory_managment.sh 
source $current_directory/utils/regex.sh 
source $current_directory/utils/grant_permissions_directories.sh 
source $current_directory/utils/text_processor.sh 

# Parse command-line options
parse_inputs_PBT_single_CPU $@
# while [[ $# -gt 0 ]]; do
#     case "$1" in
#         -f|--File_type)
#             shift
#             case "$1" in
#                 fna|faa|features.tab|ffn|frn|gff|pathway.tab|spgene.tab|subsystem.tab)
#                     File_type="$1"
#                     ;;
#                 *)
#                     echo -e "\e[31mError: Invalid FILE_TYPE (-f ).\e[0m"
#                     usage_slurm
#                     ;;
#             esac
#             ;;
#         -o|--genomes_saving_directory)
#             shift
#             genome_saving_directory="$1"
#             ;;
#         -i|--Address_to_genome_id_text_file)
#             shift
#             Address_to_genome_id_text_file="$1"
#             ;;
#         -report)
#             # If -report is provided, run command_Y and exit
#             report=1
#             shift
#             ;;
#         -h|--help)
#             usage_slurm
#             ;;
#         *)
#             echo -e "\e[31mError: Unknown option $1\e[0m"
#             usage_slurm
#             ;;
#     esac
#     shift
# done





# Reporting the variables
echo "File_type: $File_type"
echo "genome_saving_directory: $genome_saving_directory"
echo "Address_to_genome_id_text_file: $Address_to_genome_id_text_file"
echo "report: $( [ "$report" -eq 1 ] && echo "Yes!" || echo "No!" )"


# +-------------------------- main code ---------------------------+

# Creating temporaty directory
temporary_directory=${current_directory}"/temp"
create_directory $temporary_directory


# removing the temporary files except log files to prevent any problem in the list of remaining and downloaded files generated at the end!
#rm -f "${temporary_directory}"/*

# #This part creates .sh file optimized based 
# # on the system of the genome id files used 

# reading the textfile containing the genome IDs
text_file_finder_and_sanity_checker_corrector $Address_to_genome_id_text_file



# Creating a copy of the textfile to keep track of the genomes that could not be downloaded.  ==> changed the algorithm and moved to the end
# suffix="${Address_to_genome_id_text_file##*.}"  # Extract suffix
# base_name="${Address_to_genome_id_text_file%.*}"  # Extract base name
# remaining_genomes="${base_name}_remaining.txt"

# # Create a copy of the genome list ID to keep track of the remaining genome
# cp "$Address_to_genome_id_text_file" "$remaining_genomes"


Number_of_genomes=$(awk 'END{print NR}' "$Address_to_genome_id_text_file")
echo "Number of genomes to be downloaded:" $Number_of_genomes

create_directory ${genome_saving_directory}


if [ $report -eq 1 ]; then
    Address_Downloaded_genomes_file=$current_directory/Downloaded_genomes.csv
    Address_Failed_genomes=$current_directory/Failed_genomes.csv
    # Creating these text files or making them empty
    echo "Genome ID" > $Address_Downloaded_genomes_file
    echo "Genome ID" > $Address_Failed_genomes
fi


INPUT_LIST=${Address_to_genome_id_text_file}

Number_of_genomes=$(wc -l < "$INPUT_LIST")

# Calculate the number of lines each CPU should process (ceiling)
lines_per_cpu=$(awk -v total="$Number_of_genomes" -v cpus="$cpus" 'BEGIN { print int((total + cpus - 1) / cpus) }')

# 2 arrays to keep track of downloaded and faild to be downloaded genomes
Downloaded_genomes=()
Failed_to_be_downloaded_genomes=()

# Calculate the start and end lines for the current job
start_line=1
end_line=$lines_per_cpu

# Process lines in the specified interval
for ((line_num = $start_line; line_num <= $end_line; line_num++)); do

    INPUT_FILE=$(sed -n "${line_num}p" "$INPUT_LIST")

    echo "Downloading genome ID $INPUT_FILE, .$File_type file from DV-BRC database"
    genome_saving_address=${genome_saving_directory}/${INPUT_FILE}.$File_type


    # Checking the genome is already downloaded
    if [ ! -f "$genome_saving_address" ]; then

        echo -e "\e[32m$INPUT_FILE.$File_type is being downloaded!\e[0m"

        if wget -qN -P "${genome_saving_directory}" "ftp://ftp.bvbrc.org/genomes/${INPUT_FILE}/${INPUT_FILE}.$File_type"; then
        # Command was successful
            echo -e "\e[32m$INPUT_FILE.$File_type successfuly downloaded!!!!!!!\e[0m"  # Green text
            #echo \${INPUT_FILE} > \$temporary_downloaded_files_list # No temporary files any more needed
            Downloaded_genomes+=(${INPUT_FILE})
            [ "$report" -eq 1 ] && echo $INPUT_FILE >> $Address_Downloaded_genomes_file
        else 
            # download failed
            echo -e "\e[31m$INPUT_FILE.$File_type failed to be downloaded!!!!!!\e[0m"  # Red text
            # echo \${INPUT_FILE} > \$temporary_failed_files_list # No temporary files used
            Failed_to_be_downloaded_genomes+=(${INPUT_FILE})
            [ "$report" -eq 1 ] && echo $INPUT_FILE >> $Address_Failed_genomes
        fi

    else # it is already downloaded
        echo "$INPUT_FILE.$File_type is already downloaded exists in the dataset directory!"
        #echo \${INPUT_FILE} >> \$temporary_downloaded_files_list # No temporary files used
        Downloaded_genomes+=(${INPUT_FILE}) 
        [ "$report" -eq 1 ] && echo $INPUT_FILE >> $Address_Downloaded_genomes_file

    fi  

done

[ "$report" -eq 1 ] && echo -e "\e[32mReports are available at $Address_Downloaded_genomes_file and $Address_Failed_genomes\e[0m"  # Green text
[ "$report" -eq 1 ] && echo -e "\e[35mFeel free to repeat the same command used in case downloaded the rest of genomes that could not be downloaded, the previously downloaded data wont be redownloaded and the input textfile wolud not needed to be changed!\e[0m"  # Green text
echo The downloaded genomes are available at $Address_to_genome_id_text_file
