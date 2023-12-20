# Project Name

Brief description or introduction to your project.

## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Getting Started

Explain how to get started with your project. Provide steps to install, configure, and use the project.

### Prerequisites

List any software or dependencies that need to be installed before running your project.

### Installation

Provide step-by-step instructions on how to install your project.

## Usage

Usage: sh Patric_genome_downloader/Slurm_FTP_downloader.sh -o GENOMES_SAVING_DIRECTORY -i ADDRESS_TO_GENOME_ID_TEXT_FILE -f FILE_TYPE [options]

### Required arguments:

- **-o, --genomes_saving_directory GENOME_DIRECTORY**: Specify the directory for saving genomes

- **-i, --Address_to_genome_id_text_file FILE**: Specify the text file containing genome IDs

- **-f, --File_type FILE_TYPE**: Specify the file type

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

- **-rwXg**: Enable group read and execute access (default: 0)

- **-m, --memory VALUE**: Set the memory limit (default: 10)

- **-c, --cpus VALUE**: Set the number of CPUs (default: 2)

- **-t, --time_limit VALUE**: Set the time limit in hours (default: 20)

- **-l, --logs**: Enable debugging logs (default: 1)

- **-h, --help**: Display this help message

## Contributing

Explain how others can contribute to your project. Include guidelines, code of conduct, etc.

