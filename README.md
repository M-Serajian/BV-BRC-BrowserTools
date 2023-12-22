# PatricBrowserTools

## How to Cite

If you use the you used this tool in your study, please cite our paper:

- M.Serajian et al. "Title of Your Paper." Journal Name, 2024.
  - [Link to Your Paper](link-to-your-paper)

## Introduction
The **PatricBrowserTools** is a suite of powerful Bash scripts designed to facilitate the retrieval of genomic data from the PATRIC database. The suite includes two main tools: **Slurm_FTP_downloader.sh** and **Single_CPU_FTP_downloader.sh**.

### PatricBrowserTools_Slurm.sh

The Slurm-enabled version, **PatricBrowserTools_Slurm.sh**, generates Bash scripts compatible with Slurm, enabling the parallelization of the data retrieval process. This is achieved by dynamically adjusting the number of CPUs utilized, thereby significantly enhancing the efficiency of genomic data retrieval. 

The created script will be placed in the temporary repository, "temp" and submitted based on the default CPU, memory, and time_limit values. These default values can be modified using the corresponding command-line arguments.

If the `-l` flag is included in the inputs, log files will be stored in the "temp" directory, providing a quick way to monitor the process. 

If the `-report` flag is included in the inputs, two CSV files will be generated. One CSV file will contain the list of successfully downloaded genomes, and the other will list the genomes that failed to download.


Additionally, the software can disregard the data that is already retrieved. This feature is advantageous in case of errors during the process, allowing for a redo without starting the download from scratch.

### PatricBrowserTools_Single_CPU.sh

For users who prefer a single CPU approach, the **PatricBrowserTools_Single_CPU.sh** version is available. This version simplifies the data retrieval process by utilizing a single CPU, providing a straightforward and efficient solution for users with specific computational requirements.



## Table of Contents
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
  - [PatricBrowserTools_Slurm](#PatricBrowserTools_Slurm)
  - [PatricBrowserTools_Single_CPU](#PatricBrowserTools_Single_CPU)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)


## Getting Started 
```
git clone https://github.com/M-Serajian/PatricBrowserTools.git
```
### Prerequisites
There are no prerequisites needed!
### Installation
No installation is not needed! It can be cloned, and it is ready to be used. 

## Usage
### PatricBrowserTools_Slurm Usage


```bash
sh PatricBrowserTools_Slurm.sh -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]
```
### Required arguments:

- **`-o`, `--genomes_directory` GENOME_DIRECTORY**: Specify the directory for store downloaded genomes

- **`-i`, `--Address_to_genome_id_text_file` FILE**: Specify the text file containing genome IDs

- **`-f`, `--File_type` FILE_TYPE**: Specify the file type

### Valid FILE_TYPE options:

- **fna**: FASTA contig sequences

- **faa**: FASTA protein sequence file

- **features.tab**: All genomic features and related information in tab-delimited format

- **ffn**: FASTA nucleotide sequences for genomic features (genes, RNAs, etc.)

- **frn**: FASTA nucleotide sequences for RNAs

- **gff**: Genome annotations in GFF file format

- **pathway.tab**: Metabolic pathway assignments in tab-delimited format

- **spgene.tab**: Specialty gene assignments (AMR genes, virulence factors, essential genes, etc.) in tab-delimited format

- **subsystem.tab**: Subsystem assignments in tab-delimited format

### Optional arguments:
- **`-m`, `--memory` VALUE**: Set the memory limit (default: 10)

- **`-c`, `--cpus` VALUE**: Set the number of CPUs (default: 2)

- **`-t`, `--time_limit` VALUE**: Set the time limit in hours (default: 20)

- **`-l`, `--logs`**: Enable debugging logs

- **`-report`, `--report`**: Create CSV files of downloaded and failed to be downloaded genomes

- **`-h`, `--help`**: Display this help message

### Examples

```bash
sh PatricBrowserTools_Slurm.sh -f fna -o genomes_DIR -i Genome_IDs.txt
```
Here, PatricBrowserTools will initiate a Slurm job array, in the "temp" directory, specifying the allocation of 2 CPUs as the default configuration. The job's objective is to retrieve genomic data from a list specified in the "Genome_IDs.txt" file. The computational workload is parallelized, with the first CPU tasked to download the initial portion of genomic data, while the second CPU concurrently retrieves the remaining half of the data. 

```bash
sh PatricBrowserTools_Slurm.sh -f fna -o genomes_DIR -i Genome_IDs.txt  -c 90 -m 8 -l 1
```
In this setup, 90 CPUs with 8GB of memory each are allocated for a data retrieval task, and log files are stored in the "log" directory within the "temp" directory. 



### PatricBrowserTools_Single_CPU Usage

```bash
sh PatricBrowserTools_Single_CPU.sh -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]
```

### Required arguments:

- **`-o`, `--genomes_directory` GENOME_DIRECTORY**: Specify the directory for store downloaded genomes

- **`-i`, `--Address_to_genome_id_text_file` FILE**: Specify the text file containing genome IDs

- **`-f`, `--File_type FILE_TYPE`**: Specify the file type

### Valid FILE_TYPE options:

- **fna**: FASTA contig sequences

- **faa**: FASTA protein sequence file

- **features.tab**: All genomic features and related information in tab-delimited format

- **ffn**: FASTA nucleotide sequences for genomic features (genes, RNAs, etc.)

- **frn**: FASTA nucleotide sequences for RNAs

- **gff**: Genome annotations in GFF file format

- **pathway.tab**: Metabolic pathway assignments in tab-delimited format

- **spgene.tab**: Specialty gene assignments (AMR genes, virulence factors, essential genes, etc.) in tab-delimited format

- **subsystem.tab**: Subsystem assignments in tab-delimited format

### Optional arguments:
- **`-report`, `--report`**: Create CSV files of downloaded and failed to be downloaded genomes

- **`-h`, `--help`**: Display this help message

## Configuration
The primary information required to retrieve data from BV-BRC consists of genome IDs associated with various BACTERIAL AND VIRAL metadata, available at https://www.bv-brc.org/. Extract the desired genome IDs and store them in a text file. This software is not sensitive to white vertical spaces between two consecutive genome IDs; it automatically removes such spaces from the text file and saves the cleaned information in the same file containing genome IDs. Subsequently, the tool initiates the download process.



## Contributing

Interested contributors are encouraged to follow the guidelines outlined in [CONTRIBUTING.md](https://github.com/M-Serajian/PatricBrowserTools/blob/main/CONTRIBUTING.md) when participating in the development of this tool.

## License
This project is licensed under the GPL-3.0 license - see the [LICENSE](LICENSE) file for details.
