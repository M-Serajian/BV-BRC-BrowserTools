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
# This path variable is created to be able to run Patric_genome_downloader
# from any directorys in system using absolute path
Patric_genome_downloader_DIR="$(dirname "$(readlink -f "$0")")"

# Check if the current directory is not equal to the target directory
# This will make the software easily executable from any directories on the system


# if [ "$PWD" != "$Patric_genome_downloader_DIR" ]; then
#     # Change the working directory to the target directory
#     cd "$Patric_genome_downloader_DIR" || { echo -e "\e[31mError occurred changing the working directory to directory of Patric_genome_downloader, program aborted!\e[0m"; exit 2; }
# fi   # Followin function | | |
#                          V V V
aanpasbaar_runing $PWD $Patric_genome_downloader_DIR

current_directory=$(pwd)
echo "the current working directory is :$current_directory"
#Processing args


#loading utilities and used libraries 
source $current_directory/utils/directory_managment.sh 
source $current_directory/utils/regex.sh 
source $current_directory/utils/grant_permissions_directories.sh 
source $current_directory/utils/text_processor.sh


# Processing arguments
# Default values for optional arguments
memory=10
cpus=2
time_limit=20
logs=0

# Parse command-line options
parse_inputs_PBT_Slurm "$@"

echo "memory: $memory"
echo "cpus: $cpus"
echo "time_limit: $time_limit"
echo "logs: $logs"
echo "File_type: $File_type"
echo "genome_saving_directory: $genome_saving_directory"
echo "Address_to_genome_id_text_file: $Address_to_genome_id_text_file"
echo "report: $( [ "$report" -eq 1 ] && echo "Yes!" || echo "No!" )"



Needed_memory="$memory"gb
Process_time=$time_limit:00:00

# Slrum specifications
Main_job_action_name="DV_BRC_genome_downloader"
log_files_address=${current_directory}"/temp/logs_"${Main_job_action_name}
slurm_script_address=${current_directory}/temp/${Main_job_action_name}.sh
Array_job_list=1-${cpus} 


# +-------------------------- main code ---------------------------+

# Creating temporaty directory
temporary_directory=${current_directory}"/temp"
create_directory $temporary_directory


# removing the temporary files except log files to prevent any problem in the list of remaining and downloaded files generated at the end!
#rm -f "${temporary_directory}"/*

# Creating log directory for the debug 
if [ $logs -eq 1 ]; then
    create_directory ${log_files_address}
fi

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


cat << EOF > ${slurm_script_address}
#!/bin/bash
#SBATCH --job-name=${Main_job_action_name}
#SBATCH --mail-type=ALL            # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=${Mail_user}   # Where to send mail
#SBATCH --ntasks=1                       # Run a single task
#SBATCH --mem=${Needed_memory}                        # Job Memory
#SBATCH --time=${Process_time}                 # Time limit hrs:min:sec
#SBATCH --array=${Array_job_list}                  # Array range
#SBATCH --output=${log_files_address}/"$Main_job_action_name"_%A_%a.log


#Job array Id
RUN=\${SLURM_ARRAY_TASK_ID:-1}


# No temporary files are needed 
# temporary_downloaded_files_list=$temporary_directory"/finished_list"_\${RUN}.txt
# temporary_failed_files_list=$temporary_directory"/failed_list"_\${RUN}.txt
echo "RUN #\${RUN}"

INPUT_LIST=${Address_to_genome_id_text_file}

Number_of_genomes=\$(wc -l < "\$INPUT_LIST")

# Calculate the number of lines each CPU should process (ceiling)
lines_per_cpu=$(awk -v total="$Number_of_genomes" -v cpus="$cpus" 'BEGIN { print int((total + cpus - 1) / cpus) }')
echo \$lines_per_cpu is allocated to each CPU

# 2 arrays to keep track of downloaded and faild to be downloaded genomes
Downloaded_genomes=()
Failed_to_be_downloaded_genomes=()

# Calculate the start and end lines for the current job
start_line=\$(((SLURM_ARRAY_TASK_ID - 1) * lines_per_cpu + 1))
end_line=\$((start_line + lines_per_cpu - 1))

if [ "\$end_line" -ge "\$total_lines" ]; then
    end_line="\$((\$Number_of_genomes - 1))"
fi
echo "starting line =" \$start_line
echo "Ending line   =" \$end_line

# Process lines in the specified interval
for ((line_num = \$start_line; line_num <= \$end_line; line_num++)); do

    INPUT_FILE=\$(sed -n "\${line_num}p" "\$INPUT_LIST")

    echo "Downloading genome ID \${INPUT_FILE}, .$File_type file from DV-BRC database"
    genome_saving_address=${genome_saving_directory}/\${INPUT_FILE}.$File_type


    # Checking the genome is already downloaded
    if [ ! -f "\$genome_saving_address" ]; then

        echo -e "\e[32m\${INPUT_FILE}.$File_type is being downloaded!\e[0m"

        if wget -qN -P "${genome_saving_directory}" "ftp://ftp.bvbrc.org/genomes/\${INPUT_FILE}/\${INPUT_FILE}.$File_type"; then
        # Command was successful
            echo -e "\e[32m\${INPUT_FILE}.$File_type successfuly downloaded!!!!!!!\e[0m"  # Green text
            #echo \${INPUT_FILE} > \$temporary_downloaded_files_list # No temporary files any more needed
            Downloaded_genomes+=(\${INPUT_FILE})
        else 
            # download failed
            echo -e "\e[31m\${INPUT_FILE}.$File_type failed to be downloaded!!!!!!\e[0m"  # Red text
            # echo \${INPUT_FILE} > \$temporary_failed_files_list # No temporary files used
            Failed_to_be_downloaded_genomes+=(\${INPUT_FILE})
        fi

    else # it is already downloaded
        echo "\${INPUT_FILE}.$File_type is already downloaded exists in the dataset directory!"
        #echo \${INPUT_FILE} >> \$temporary_downloaded_files_list # No temporary files used
        Downloaded_genomes+=(\${INPUT_FILE}) 
    fi  

done




echo The batch of .$File_type files in $Address_to_genome_id_text_file text file are downloaded!



if [ $report -eq 1 ]; then
{
    {
        flock -x 200

        # Write each element of the array to the file
        for genome in "\${Downloaded_genomes[@]}"; do
            echo "\$genome" >> $Address_Downloaded_genomes_file
        done

    } 200>>"$Address_Downloaded_genomes_file"  # Use file descriptor 200 to acquire the lock
    {
        flock -x 200

        # Write each element of the array to the file
        for genome in "\${Failed_to_be_downloaded_genomes[@]}"; do
            echo "\$genome" >> $Address_Failed_genomes
        done

    } 200>>"$Address_Failed_genomes"  # Use file descriptor 200 to acquire the lock

    echo -e "\e[32mReports are available at $Address_Downloaded_genomes_file and $Address_Failed_genomes\e[0m"  # Green text
    echo -e "\e[35mFeel free to repeat the same command used in case downloaded the rest of genomes that could not be downloaded, the previously downloaded data wont be redownloaded and the input textfile wolud not needed to be changed!\e[0m"  # Green text  
}
fi


EOF

sbatch ${slurm_script_address}

echo ${Main_job_action_name} is submitted!
echo The downloaded genomes will be available at $Address_to_genome_id_text_file

