#!/bin/bash

# Function to display valid FILE_TYPE options in green
File_type_usage() {
  GREEN=$(tput setaf 2)
  RESET=$(tput sgr0)

  echo "Valid ${GREEN}FILE_TYPE${RESET} options:"
  echo "  ${GREEN}fna${RESET}          FASTA contig sequences"
  echo "  ${GREEN}faa${RESET}          FASTA protein sequence file"
  echo "  ${GREEN}features.tab${RESET} All genomic features and related information in tab-delimited format"
  echo "  ${GREEN}ffn${RESET}          FASTA nucleotide sequences for genomic features (genes, RNAs, etc.)"
  echo "  ${GREEN}frn${RESET}          FASTA nucleotide sequences for RNAs"
  echo "  ${GREEN}gff${RESET}          Genome annotations in GFF file format"
  echo "  ${GREEN}pathway.tab${RESET}  Metabolic pathway assignments in tab-delimited format"
  echo "  ${GREEN}spgene.tab${RESET}   Specialty gene assignments (AMR genes, virulence factors, essential genes, etc.)"
  echo "  ${GREEN}subsystem.tab${RESET} Subsystem assignments in tab-delimited format"
}


# ----------------------------- Single CPU part ---------------------
usage_single_cpu() {
    echo -e "Usage: $(basename "$0") \e[34m-o\e[0m GENOMES_SAVING_DIRECTORY \e[34m-i\e[0m ADDRESS_TO_GENOME_ID_TEXT_FILE \e[34m-f\e[0m FILE_TYPE [options]"
    echo -e "Options (\e[34mRequired\e[0m + Optional): "
    echo -e "  \e[34m-o, --genomes_saving_directory\e[0m \e[34m<directory>\e[0m  Specify the directory for saving genomes."
    echo -e "  \e[34m-i, --Address_to_genome_id_text_file \e \e[34m<file>\e[0m Specify the address to the genome ID text file."
    echo -e "  \e[34m-f, --File_type \e[0m  \e[34m<type>\e[0m       Specify the file type (fna, faa, features.tab, ff‌n, frn, gff, pathway.tab, spgene.tab, subsystem.tab)."
    File_type_usage
    echo "  -report                      Include this flag to generate a report."
    echo "  -h, --help                   Display this help message."
    exit 1
}



parse_inputs_PBT_single_CPU() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--File_type)
                shift
                case "$1" in
                    fna|faa|features.tab|ffn|frn|gff|pathway.tab|spgene.tab|subsystem.tab)
                        File_type="$1"
                        ;;
                    *)
                        echo -e "\e[31mError: Invalid FILE_TYPE (-f ).\e[0m"
                        usage_single_cpu
                        ;;
                esac
                ;;
            -o|--genomes_saving_directory)
                shift
                genome_saving_directory="$1"
                ;;
            -i|--Address_to_genome_id_text_file)
                shift
                Address_to_genome_id_text_file="$1"
                ;;
            -report)
                # If -report is provided, run command_Y and exit
                report=1
                shift
                ;;
            -h|--help)
                usage_single_cpu
                ;;
            *)
                echo -e "\e[31mError: Unknown option $1\e[0m"
                usage_single_cpu
                ;;
        esac
        shift
    done
    # Check for missing required arguments
    if [ -z "$File_type" ] || [ -z "$genome_saving_directory" ] || [ -z "$Address_to_genome_id_text_file" ]; then
        echo -e "\e[31mError: Required argument is missing!\e[0m"
        usage_single_cpu
    fi
}

# ---------------------------- End of Single CPU part----------------

# ---------------------------- Slurm section ------------------------


# Function to display usage for single cpu PatricBrowserTools
usage_slurm() {
    echo -e "Usage: $(basename "$0") \e[34m-o\e[0m GENOMES_SAVING_DIRECTORY \e[34m-i\e[0m ADDRESS_TO_GENOME_ID_TEXT_FILE \e[34m-f\e[0m FILE_TYPE [options]"
    echo -e "Options (\e[34mRequired\e[0m + Optional): "
    echo -e "  \e[34m-o, --genomes_saving_directory\e[0m \e[34m<directory>\e[0m  Specify the directory for saving genomes."
    echo -e "  \e[34m-i, --Address_to_genome_id_text_file \e \e[34m<file>\e[0m Specify the address to the genome ID text file."
    echo -e "  \e[34m-f, --File_type \e[0m  \e[34m<type>\e[0m       Specify the file type (fna, faa, features.tab, ff‌n, frn, gff, pathway.tab, spgene.tab, subsystem.tab)."
    File_type_usage   # File type usage

    echo "Optional arguments:"
    echo "  -m, --memory VALUE  Set the memory limit (default: 10)"
    echo "  -c, --cpus VALUE    Set the number of CPUs (default: 2)"
    echo "  -t, --time_limit VALUE Set the time limit in hours (default: 20)"
    echo "  -l, --logs          Enable debugging logs (default: 1)"
    echo "  -h, --help          Display this help message"
    echo ""


    exit 1
}






parse_inputs_PBT_Slurm() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--memory)
                shift
                memory="$1"
                ;;
            -c|--cpus)
                shift
                cpus="$1"
                ;;
            -t|--time_limit)
                shift
                time_limit="$1"
                ;;
            -l|--logs)
                logs=1
                ;;
            -f|--File_type)
                shift
                case "$1" in
                    fna|faa|features.tab|ffn|frn|gff|pathway.tab|spgene.tab|subsystem.tab)
                        File_type="$1"
                        ;;
                    *)
                        echo -e "\e[31mError: Invalid FILE_TYPE (-f ).\e[0m"
                        usage_slurm
                        ;;
                esac
                ;;
            -o|--genomes_saving_directory)
                shift
                genome_saving_directory="$1"
                ;;
            -i|--Address_to_genome_id_text_file)
                shift
                Address_to_genome_id_text_file="$1"
                ;;
            -report)
                # If -report is provided, run command_Y and exit
                report=1
                shift
                ;;
            -h|--help)
                usage_slurm
                ;;
            *)
                echo -e "\e[31mError: Unknown option $1\e[0m"
                usage_slurm
                ;;
        esac
        shift
    done


    # Check for missing required arguments
    if [ -z "$File_type" ] || [ -z "$genome_saving_directory" ] || [ -z "$Address_to_genome_id_text_file" ]; then
        echo -e "\e[31mError: Required argument is missing!\e[0m"
        usage_slurm
    fi
}

# ---------------------------- End of Slurm section ----------------
