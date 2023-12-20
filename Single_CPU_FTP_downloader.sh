#!/bin/bash

date;hostname;pwd


current_directory=$(pwd)
chmod -R g+rwX ${current_directory}

#This code creates .sh file optimized based on the system of the genome id files used 
Main_job_action_name="DV_BRC_genome_downloader_fna_modified"

Needed_memory=80gb

number_of_accessible_CPUs=10

Process_time=20:00:00

Address_to_genome_id_text_file="/home/m.serajian/projects/MTB_Scientific_reports/data/Unique_Genome_IDs.txt"

Number_of_genomes=$(awk 'END{print NR}' "$Address_to_genome_id_text_file")

echo "Number of genomes to be downloaded:" $Number_of_genomes
Array_job_list=1-${number_of_accessible_CPUs} 
Mail_user=m.serajian@ufl.edu

genome_saving_directory="/blue/boucher/share/MTB_Database/DV-BRC-Sientific-reports-Jan2024"
mkdir -p ${genome_saving_directory}
chmod -R g+rwX ${genome_saving_directory}
# Tmporary directory for log files and debug
mkdir -p ${current_directory}"/temp"


log_files_address=${current_directory}"/temp/logs_"${Main_job_action_name}
mkdir -p ${log_files_address} #for saving the logs

slurm_script_address=${current_directory}/temp/${Main_job_action_name}.sh


cat << EOF > ${slurm_script_address}
#!/bin/bash
#SBATCH --job-name=${Main_job_action_name}
#SBATCH --mail-type=ALL            # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=${Mail_user}   # Where to send mail
#SBATCH --ntasks=1                       # Run a single task
#SBATCH --mem=${Needed_memory}                        # Job Memory
#SBATCH --time=${Process_time}                 # Time limit hrs:min:sec
#SBATCH --array=${Array_job_list}                  # Array range
#SBATCH --output=${log_files_address}/"$Main_job_name"_%A_%a.log
  

RUN=\${SLURM_ARRAY_TASK_ID:-1}

echo "RUN #\${RUN}"

INPUT_LIST=${Address_to_genome_id_text_file}

Number_of_genomes=\$(wc -l < "\$INPUT_LIST")

# Calculate the number of lines each CPU should process (ceiling)
lines_per_cpu=$(awk -v total="$Number_of_genomes" -v cpus="$number_of_accessible_CPUs" 'BEGIN { print int((total + cpus - 1) / cpus) }')
echo \$lines_per_cpu is allocated to each CPU



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

    echo "Downloading genome ID \${INPUT_FILE}, .fna file from DV-BRC database"
    genome_saving_address=${genome_saving_directory}/\${INPUT_FILE}.fna
    

    # Checking the genome is already downloaded
    if [ ! -f "\$genome_saving_address" ]; then
    
        echo -e "\e[32m\${INPUT_FILE}.fna is being downloaded!\e[0m"

        if wget -qN -P "${genome_saving_directory}" "ftp://ftp.bvbrc.org/genomes/\${INPUT_FILE}/\${INPUT_FILE}.fna"; then
        # Command was successful
            echo -e "\e[32m\${INPUT_FILE}.fna successfuly downloaded!!!!!!!\e[0m"  # Green text
        else
            # Command failed
            echo -e "\e[31m\${INPUT_FILE}.fna failed to be downloaded!!!!!!\e[0m"  # Red text
        fi
    
    else # starting to download the genome
        echo "\${INPUT_FILE}.fna is already downloaded exists in the dataset directory!"
    fi  

done

echo The batch of gemones downloaded!
echo Finished!!!

EOF

chmod g+rwX ${slurm_script_address}

sbatch ${slurm_script_address}

echo ${Main_job_action_name} is submitted!

