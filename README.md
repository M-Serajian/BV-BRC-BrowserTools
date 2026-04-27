# BV-BRC-BrowserTools

## Introduction

**BV-BRC-BrowserTools** retrieves genomic data files from the
[BV-BRC](https://www.bv-brc.org/) FTP server. The tool is portable: the same
command runs on a laptop and on an HPC cluster — the underlying scheduler is
auto-detected, and the workload is parallelized accordingly. Re-running the
same command resumes where it left off; previously-downloaded files are
skipped, so interrupted runs do not need to start over. An optional
`--report` flag produces CSVs of successful and failed downloads.

The tool is implemented as a single, dependency-free Python 3 script
([bv_brc_browser_tools.py](bv_brc_browser_tools.py)). The original Bash
implementation is preserved under [old/](old/) for reference.

## How to Cite

If you used this tool in your study, please cite:

- M. Serajian et al. *"A comparative study of antibiotic resistance patterns in Mycobacterium tuberculosis."* Scientific Reports, 2025.
  - [Link to the paper](https://www.nature.com/articles/s41598-025-89087-w)

## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
  - [Required arguments](#required-arguments)
  - [Optional arguments](#optional-arguments)
  - [Valid file types](#valid-file-types)
- [Quick test](#quick-test)
- [Examples](#examples)
- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)

## Getting Started

```bash
git clone https://github.com/M-Serajian/BV-BRC-BrowserTools.git
cd BV-BRC-BrowserTools
chmod +x bv_brc_browser_tools.py
```

### Prerequisites

- Python 3.8+ (standard library only — no `pip install` needed)
- [`wget`](https://www.gnu.org/software/wget/) on `PATH` (recommended; the BV-BRC
  FTP endpoint requires FTPS, which Python's `urllib` does not implement). The
  script falls back to `urllib` over HTTPS when `wget` is unavailable.

### Installation

No installation step is required. Clone the repo and run the script directly.

## Usage

```bash
./bv_brc_browser_tools.py -o GENOMES_DIR -i GENOME_IDS.txt -f FILE_TYPE [options]
```

### Required arguments

| Flag | Description |
| ---- | ----------- |
| `-o`, `--output`, `--genomes_saving_directory` | Directory where downloaded files are saved. |
| `-i`, `--input`, `--Address_to_genome_id_text_file` | Text file with one BV-BRC genome ID per line. |
| `-f`, `--File_type` | File type to retrieve (see below). |

### Optional arguments

| Flag | Default | Description |
| ---- | ------- | ----------- |
| `-c`, `--cpus` | `2` | Parallel workers. On a cluster: number of array tasks. Locally: number of concurrent download threads. |
| `-m`, `--memory` | `10` | Memory per task in GB. Cluster only. |
| `-t`, `--time_limit` | `20` | Wall time per task in hours. Cluster only. |
| `-l`, `--logs` | off | Write per-task logs into `./temp/logs_*`. Cluster only. |
| `--report` | off | Write `Downloaded_genomes.csv` and `Failed_genomes.csv` at the end. Locking is used so concurrent tasks can append safely. |
| `--scheduler {auto,slurm,pbs,lsf,sge,local}` | `auto` | Backend selection. `auto` probes the environment. |
| `--local` | off | Force local mode even when a scheduler is detected. |
| `--mail-user EMAIL` | `$USER_EMAIL` | Email for cluster job notifications. |
| `--retries N` | `2` | Per-genome download retries on failure. |
| `--timeout SECONDS` | `120` | Per-download timeout. |
| `--temp-dir DIR` | `./temp` | Where submit scripts and task logs are written. |
| `-h`, `--help` | — | Display help. |

> **Compatibility:** `-report` (single dash, as in the original Bash tool) is
> still accepted.

### Valid file types

| Type | Description |
| ---- | ----------- |
| `fna` | FASTA contig sequences |
| `faa` | FASTA protein sequence file |
| `features.tab` | All genomic features and related information (tab-delimited) |
| `ffn` | FASTA nucleotide sequences for genomic features (genes, RNAs, etc.) |
| `frn` | FASTA nucleotide sequences for RNAs |
| `gff` | Genome annotations (GFF) |
| `pathway.tab` | Metabolic pathway assignments (tab-delimited) |
| `spgene.tab` | Specialty gene assignments (AMR, virulence, essential genes, etc.) |
| `subsystem.tab` | Subsystem assignments (tab-delimited) |

## Quick test

A sample list of *Mycobacterium tuberculosis* genome IDs is included under
[data/mtb_genome_ids.txt](data/mtb_genome_ids.txt). Use it to verify your
setup before running on a full dataset:

```bash
# Download FASTA assemblies for 8 M. tuberculosis genomes (local, 4 threads)
./bv_brc_browser_tools.py \
    -f fna \
    -i data/mtb_genome_ids.txt \
    -o test_output/ \
    -c 4 \
    --report
```

Expected output: a `test_output/` directory containing one `.fna` file per
genome ID, plus `Downloaded_genomes.csv` and `Failed_genomes.csv` in the
project root.

The genome IDs in `data/mtb_genome_ids.txt` correspond to publicly available
*M. tuberculosis* assemblies deposited in
[BV-BRC](https://www.bv-brc.org/). These genomes were used in the
comparative study of antibiotic resistance patterns cited above.

## Examples

```bash
# Local: 8 concurrent download threads, with a CSV report.
./bv_brc_browser_tools.py -f fna -o genomes/ -i Genome_IDs.txt -c 8 --report
```

```bash
# Cluster: auto-detected (Slurm/PBS/LSF/SGE). 90 array tasks, 8 GB each, logs on.
./bv_brc_browser_tools.py -f fna -o genomes/ -i Genome_IDs.txt \
    -c 90 -m 8 -t 20 -l --report
```

```bash
# Force local mode even if a scheduler is on PATH (useful on login nodes
# for small batches):
./bv_brc_browser_tools.py -f fna -o genomes/ -i Genome_IDs.txt -c 4 --local
```

## How it works

1. **Input sanitation.** The genome ID list is loaded; blank/whitespace-only
   lines are removed in place.
2. **Backend selection.** The script probes for `sbatch` (Slurm), `bsub`
   (LSF), or `qsub` (PBS/SGE, disambiguated via `SGE_ROOT`/`pbsnodes`/etc.).
   With no scheduler — or with `--local` — the work runs in-process via a
   `ThreadPoolExecutor` sized to `--cpus`.
3. **Cluster mode.** The script writes a submit script under `--temp-dir`
   tailored to the detected scheduler and submits an array job of `--cpus`
   tasks. Each task re-invokes the same script with `--worker --chunk-id N
   --total-chunks K` and processes its slice of the genome list serially.
4. **Resume.** Each task skips genomes whose target file already exists and
   is non-empty. Re-running the same command picks up only the remaining
   genomes.
5. **Reports (optional).** When `--report` is set, `Downloaded_genomes.csv`
   and `Failed_genomes.csv` are created in the project root and appended to
   under an `fcntl` exclusive lock so concurrent tasks do not interleave.

## Configuration

The primary input is a list of BV-BRC genome IDs corresponding to bacterial
or viral metadata, available at [BV-BRC](https://www.bv-brc.org/). Extract
the desired genome IDs and store them, one per line, in a plain text file.
Blank lines are tolerated — the script removes them and rewrites the file in
place before downloading.

## Contributing

Contributions are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the GPL-3.0 license — see [LICENSE](LICENSE).
