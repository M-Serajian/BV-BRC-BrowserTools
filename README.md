# BV-BRC-BrowserTools

## Introduction
The **BV-BRC-BrowserTools** is a suite of powerful Bash scripts designed to facilitate the retrieval of genomic data from the BV-BRC database. The primary advantage of BV-BRC-BrowserTools is  its ability to seamlessly resume processing at any point within the workflow. In the event of an interruption, the tool, when rerun without alterations to the genome list—provided they remain valid according to [BV-BRC](https://www.bv-brc.org/)— picks up precisely where it left off. Furthermore, the tool streamlines data processing efficiency by generating a comprehensive CSV report. The suite includes two main tools: **BV-BRC-BrowserTools_Slurm.sh** and **BV-BRC-BrowserTools_Single_CPU.sh**.

## How to Cite

If you use the you used this tool in your study, please cite our paper:

- M.Serajian et al. "Title of Your Paper." Journal Name, 2024.
  - [Link to The Paper](link-to-the-paper)


### BV-BRC-BrowserTools_Slurm.sh

The Slurm-enabled version, **BV-BRC-BrowserTools_Slurm.sh**, generates Bash scripts compatible with Slurm, enabling the parallelization of the data retrieval process. This is achieved by dynamically adjusting the number of CPUs utilized, thereby significantly enhancing the efficiency of genomic data retrieval. 

The created script will be placed in the temporary repository, "temp" and submitted based on the default CPU, memory, and time_limit values. These default values can be modified using the corresponding command-line arguments.

If the **`-l`** flag is included in the inputs, log files will be stored in the "temp" directory, providing a quick way to monitor the process. 

If the **`-report`** flag is included in the inputs, two CSV files will be generated. One CSV file will contain the list of successfully downloaded genomes, and the other will list the genomes that failed to download.


Additionally, the software can disregard the data that is already retrieved. This feature is advantageous in case of errors during the process, allowing for a redo without starting the download from scratch.

### BV-BRC-BrowserTools_Single_CPU.sh

For users who prefer a single CPU approach, the **BV-BRC-BrowserTools_Single_CPU.sh** version is available. This version simplifies the data retrieval process by utilizing a single CPU, providing a straightforward and efficient solution for users with specific computational requirements.
Moreover, **`-report`** works the same for BV-BRC-BrowserTools_Single_CPU; however, it does not have **`-l`** since it is a single CPU and the process can be tracked directly on the terminal.


## Table of Contents
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
  - [BV-BRC-BrowserTools_Slurm](#BV-BRC-BrowserTools_Slurm)
  - [BV-BRC-BrowserTools_Single_CPU](#BV-BRC-BrowserTools_Single_CPU)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)


## Getting Started 
```
git clone https://github.com/M-Serajian/BV-BRC-BrowserTools.git
```
### Prerequisites
[Wget](https://www.gnu.org/software/wget/)
### Installation
No installation is not needed! It can be cloned, and it is ready to be used. 

## Usage
### BV-BRC-BrowserTools_Slurm Usage


```bash
sh BV-BRC-BrowserTools_Slurm.sh -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]
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
sh BV-BRC-BrowserTools_Slurm.sh -f fna -o genomes_DIR -i Genome_IDs.txt
```
Here, BV-BRC-BrowserTools will initiate a Slurm job array, in the "temp" directory, specifying the allocation of 2 CPUs as the default configuration. The job's objective is to retrieve genomic data from a list specified in the "Genome_IDs.txt" file. The computational workload is parallelized, with the first CPU tasked to download the initial portion of genomic data, while the second CPU concurrently retrieves the remaining half of the data. 

```bash
sh BV-BRC-BrowserTools_Slurm.sh -f fna -o genomes_DIR -i Genome_IDs.txt  -c 90 -m 8 -l -report
```
In this setup, 90 CPUs with 8GB of memory each are allocated for a data retrieval task, and log files are stored in the "log" directory within the "temp" directory. 2 CSV files will be created in the main directory of BV-BRC-BrowserTools to report the downloaded genomes and the ones that failed. 



### BV-BRC-BrowserTools_Single_CPU Usage

```bash
sh BV-BRC-BrowserTools_Single_CPU.sh -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]
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
The primary information required to retrieve data from BV-BRC consists of genome IDs associated with various BACTERIAL AND VIRAL metadata, available at [BV-BRC](https://www.bv-brc.org/). Extract the desired genome IDs and store them in a text file. This software is not sensitive to white vertical spaces between two consecutive genome IDs; it automatically removes such spaces from the text file and saves the cleaned information in the same file containing genome IDs. Subsequently, the tool initiates the download process.



## Contributing

Interested contributors are encouraged to follow the guidelines outlined in [CONTRIBUTING.md](https://github.com/M-Serajian/BV-BRC-BrowserTools/blob/main/CONTRIBUTING.md) when participating in the development of this tool.

## License
This project is licensed under the GPL-3.0 license - see the [LICENSE](LICENSE) file for details.
