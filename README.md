# PatricBrowserTools

## Description

The **PatricBrowserTools** is a suite of powerful Bash scripts designed to facilitate the retrieval of genomic data from the PATRIC database. The suite includes two main tools: **Slurm_FTP_downloader.sh** and **Single_CPU_FTP_downloader.sh**.

### Slurm_FTP_downloader.sh

The Slurm-enabled version, **Slurm_FTP_downloader.sh**, generates Bash scripts compatible with Slurm, enabling the parallelization of the data retrieval process. This is achieved by dynamically adjusting the number of CPUs utilized, thereby significantly enhancing the efficiency of genomic data retrieval. The created script will be placed in the temporary repository and submitted based on the default CPU, memory, and time_limit values. These default values can be modified using the corresponding command-line arguments. If the `-l` flag is set to 1, log files will be stored in the temporary directory, providing a quick way to monitor the process. Additionally, the software can disregard the data that is already retrieved. This feature is advantageous in case of errors during the process, allowing for a redo without starting the download from scratch.

```bash
sh Slurm_FTP_downloader.sh -f fna -o genomes_DIR -i Genome_IDs.txt
```
In this scenario, PatricBrowserTools will initiate a Slurm job array, in the temp directory, specifying the allocation of 2 CPUs as the default configuration. The job's objective is to retrieve genomic data from a list specified in the "Genome_IDs.txt" file. The computational workload is parallelized, with the first CPU tasked to download the initial portion of genomic data, while the second CPU concurrently retrieves the remaining half of the data. 

```bash
sh Slurm_FTP_downloader.sh -f fna -o genomes_DIR -i Genome_IDs.txt  -c 90 -m 8 -l 1
```
In this setup, 90 CPUs with 8GB of memory each are allocated for a data retrieval task, and log files are stored in the "log" directory within the "temp" directory. 

### Single_CPU_FTP_downloader.sh

For users who prefer a single CPU approach, the **Single_CPU_FTP_downloader.sh** version is available. This version simplifies the data retrieval process by utilizing a single CPU, providing a straightforward and efficient solution for users with specific computational requirements.



## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Usage

```bash
sh Patric_genome_downloader/Slurm_FTP_downloader.sh -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]

## Getting Started

Explain how to get started with your project. Provide steps to install, configure, and use the project.

### Prerequisites

No prerequisites! 


### Installation

Provide step-by-step instructions on how to install your project.

## Usage
