#!/bin/bash

# this function grants Read, Write, and Execute permissions 
grant_permissions() {

    local directory="$1" #Input of the function, a local valiable

    if [ -d  "${directory}" ]; then
        # Permissions granted successfully
        echo -e "\e[33mRead, Write, and Execute permissions granted to the group"\
                "for the following directory:\e[0m"
        echo -e "\e[33m${directory}\e[0m"
    else
        # Command failed
        echo -e "\e[31mPermission could not be granted for the group in the following directory:\e[0m"  # Red text
        echo -e "\e[31m${directory}\e[0m"
        echo -e "\e[31mProgram aborted!\e[0m"
        exit 2
    fi
}

create_directory() {
  local directory=$1

  # Check if the directory exists
  if [ -d "$directory" ]; then
    echo -e "\e[34mThe directory '$directory' already exists.\e[0m"  # Blue text
  else
    # Try to create the directory
    mkdir -p "$directory"

    # Check if the directory creation was successful
    if [ $? -eq 0 ]; then
      echo -e "\e[32mThe directory '$directory' has been created.\e[0m"  # Green text
    else
      echo -e "\e[31mError: The directory '$directory' could not be created.\e[0m"  # Red text
      echo -e "\e[31mProgram aborted!\e[0m"  # Red text 
      exit 2  # Abort the script with an error status
    fi
  fi
}


text_file_finder_and_sanity_checker_corrector() {
  local file_path=$1
  # Check if the file exists
  if [ -e "$file_path" ]; then
    if grep -q -E '^[\t ]*$' "$file_path"; then
    # Empty lines found, perform the process to remove them in-place
        # Use sed to remove empty lines in-place
        sed -i '/^[\t ]*$/d' "$file_path"
        echo "Empty lines removed in: $file_path"
        echo -e "\e[33mError: Empty lines removed in:'$file_path'.\e[0m"  # Red text
    fi

    # Check if the file is not empty
    if [ -s "$file_path" ]; then
      echo "The text file '$file_path' found!"
      # Do any additional processing here if needed
    else
      echo -e "\e[31mError: The text file '$file_path' is found but is empty.\e[0m"  # Red text
      echo -e "\e[31mProgram aborted!\e[0m"  # Red text
      exit 2  # Abort the script with an error status
    fi

  else
    echo -e "\e[31mError: The text file '$file_path' could not be found.\e[0m"  # Red text
    echo -e "\e[31mProgram aborted!\e[0m"  # Red text
    exit 2  # Abort the script with an error status
  fi
}


File_type_usage (){
  echo "Valid FILE_TYPE options:"
  echo "  fna          FASTA contig sequences"
  echo "  faa          FASTA protein sequence file"
  echo "  features.tab All genomic features and related information in tab-delimited format"
  echo "  ffn          FASTA nucleotide sequences for genomic features (genes, RNAs, etc.)"
  echo "  frn          FASTA nucleotide sequences for RNAs"
  echo "  gff          Genome annotations in GFF file format"
  echo "  pathway.tab  Metabolic pathway assignments in tab-delimited format"
  echo "  spgene.tab   Specialty gene assignments (AMR genes, virulence factors, essential genes, etc.)"
  echo "  subsystem.tab Subsystem assignments in tab-delimited format"

}

# Function to display usage information
usage() {
    echo "Usage: $0 -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]"
    echo "Required arguments:"
    echo "  -o, --genomes_saving_directory GENOME_DIRECTORY Specify the directory for saving genomes"
    echo "  -i, --Address_to_genome_id_text_file FILE        Specify the text file containing genome IDs"
    echo "  -f, --File_type FILE_TYPE                       Specify the file type"

    File_type_usage   # File type usage

    echo "Optional arguments:"
    echo "  -rwXg               Enable group read and execute access (default: 0)"
    echo "  -m, --memory VALUE  Set the memory limit (default: 10)"
    echo "  -c, --cpus VALUE    Set the number of CPUs (default: 2)"
    echo "  -t, --time_limit VALUE Set the time limit in hours (default: 20)"
    echo "  -l, --logs          Enable debugging logs (default: 1)"
    echo "  -h, --help          Display this help message"
    echo ""


    exit 1
}