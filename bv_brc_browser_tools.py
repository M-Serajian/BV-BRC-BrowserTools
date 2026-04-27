#!/usr/bin/env python3
"""BV-BRC genome downloader.

Downloads genome files from the BV-BRC FTP server. Auto-detects an HPC
scheduler (Slurm, PBS/Torque, LSF, SGE) and submits a job array; falls back
to local parallel mode when no scheduler is found. Re-running the same
command resumes where it left off, since already-downloaded files are
skipped.

Stdlib only. Tested on Python >= 3.8.
"""

from __future__ import annotations

import argparse
import fcntl
import math
import os
import shutil
import socket
import subprocess
import sys
import textwrap
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

VALID_FILE_TYPES: Tuple[str, ...] = (
    "fna",
    "faa",
    "features.tab",
    "ffn",
    "frn",
    "gff",
    "pathway.tab",
    "spgene.tab",
    "subsystem.tab",
)

HTTPS_BASE = "https://ftp.bvbrc.org/genomes"
FTP_BASE = "ftp://ftp.bvbrc.org/genomes"
SUPPORTED_SCHEDULERS = ("auto", "slurm", "pbs", "lsf", "sge", "local")
PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_TEMP_DIR = PROJECT_ROOT / "temp"

ANSI = {
    "reset": "\033[0m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
}


def color(text: str, name: str) -> str:
    if not sys.stdout.isatty():
        return text
    return f"{ANSI.get(name, '')}{text}{ANSI['reset']}"


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def _normalize_argv(argv: Sequence[str]) -> List[str]:
    """Map legacy single-dash long flags (-report, -help) onto argparse form."""
    legacy = {
        "-report": "--report",
        "-help": "--help",
    }
    return [legacy.get(a, a) for a in argv]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="bv_brc_browser_tools.py",
        description=(
            "Download genome files from BV-BRC. The same command works on a "
            "laptop and on an HPC cluster: the scheduler is auto-detected."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            f"""\
            Valid file types:
              fna           FASTA contig sequences
              faa           FASTA protein sequence file
              features.tab  All genomic features (tab-delimited)
              ffn           FASTA nucleotide sequences for genomic features
              frn           FASTA nucleotide sequences for RNAs
              gff           Genome annotations (GFF)
              pathway.tab   Metabolic pathway assignments (tab-delimited)
              spgene.tab    Specialty gene assignments (tab-delimited)
              subsystem.tab Subsystem assignments (tab-delimited)

            Examples:
              # Local (auto-falls-back if no scheduler found):
              ./bv_brc_browser_tools.py -f fna -o genomes/ -i ids.txt -c 8

              # Force local mode:
              ./bv_brc_browser_tools.py -f fna -o genomes/ -i ids.txt -c 8 --local

              # Slurm (auto-detected if sbatch is on PATH):
              ./bv_brc_browser_tools.py -f fna -o genomes/ -i ids.txt \\
                  -c 90 -m 8 -t 20 -l --report
            """
        ),
    )

    req = parser.add_argument_group("required")
    req.add_argument(
        "-i", "--input", "--Address_to_genome_id_text_file",
        dest="input_file",
        help="Text file with one BV-BRC genome ID per line.",
    )
    req.add_argument(
        "-o", "--output", "--genomes_saving_directory",
        dest="output_dir",
        help="Directory where downloaded genome files will be saved.",
    )
    req.add_argument(
        "-f", "--File_type",
        dest="file_type",
        choices=VALID_FILE_TYPES,
        help="File type to retrieve.",
        metavar="TYPE",
    )

    opt = parser.add_argument_group("optional")
    opt.add_argument(
        "-c", "--cpus",
        type=int, default=2,
        help="Parallel workers. On a cluster: number of array tasks. "
             "Locally: number of concurrent download threads. (default: 2)",
    )
    opt.add_argument(
        "-m", "--memory",
        type=int, default=10,
        help="Memory per task in GB. Cluster only. (default: 10)",
    )
    opt.add_argument(
        "-t", "--time_limit",
        type=int, default=20,
        help="Wall time per task in hours. Cluster only. (default: 20)",
    )
    opt.add_argument(
        "-l", "--logs",
        action="store_true",
        help="Write per-task logs into ./temp/logs_*. Cluster only.",
    )
    opt.add_argument(
        "--report",
        action="store_true",
        help="Write Downloaded_genomes.csv and Failed_genomes.csv at the end.",
    )
    opt.add_argument(
        "--scheduler",
        choices=SUPPORTED_SCHEDULERS,
        default="auto",
        help="Backend to use (default: auto-detect).",
    )
    opt.add_argument(
        "--local", dest="force_local",
        action="store_true",
        help="Force local mode even if a scheduler is detected.",
    )
    opt.add_argument(
        "--mail-user",
        default=os.environ.get("USER_EMAIL", ""),
        help="Email address for cluster job notifications.",
    )
    opt.add_argument(
        "--retries",
        type=int, default=2,
        help="Per-genome download retries on failure (default: 2).",
    )
    opt.add_argument(
        "--timeout",
        type=int, default=120,
        help="Per-download timeout in seconds (default: 120).",
    )
    opt.add_argument(
        "--temp-dir",
        default=str(DEFAULT_TEMP_DIR),
        help="Working directory for submit scripts and logs (default: ./temp).",
    )

    # Internal worker mode (used when re-invoked by a scheduler task).
    worker = parser.add_argument_group("internal (do not use directly)")
    worker.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    worker.add_argument("--chunk-id", type=int, help=argparse.SUPPRESS)
    worker.add_argument("--total-chunks", type=int, help=argparse.SUPPRESS)
    worker.add_argument("--report-dir", help=argparse.SUPPRESS)

    return parser


def validate_args(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    missing = [
        flag for flag, value in (
            ("-f/--File_type", args.file_type),
            ("-o/--output", args.output_dir),
            ("-i/--input", args.input_file),
        ) if not value
    ]
    if missing:
        parser.error(f"missing required argument(s): {', '.join(missing)}")
    if args.cpus < 1:
        parser.error("--cpus must be >= 1")
    if args.memory < 1:
        parser.error("--memory must be >= 1")
    if args.time_limit < 1:
        parser.error("--time_limit must be >= 1")


# ---------------------------------------------------------------------------
# Input file handling
# ---------------------------------------------------------------------------

def read_genome_ids(path: Path) -> List[str]:
    if not path.exists():
        sys.exit(color(f"Error: input file '{path}' not found.", "red"))
    if not path.is_file():
        sys.exit(color(f"Error: '{path}' is not a regular file.", "red"))

    with path.open("r", encoding="utf-8") as fh:
        ids = [line.strip() for line in fh if line.strip()]

    if not ids:
        sys.exit(color(f"Error: '{path}' is empty.", "red"))

    return ids


def write_clean_input(path: Path, ids: Sequence[str]) -> None:
    """Rewrite the input file without empty/whitespace-only lines."""
    raw = path.read_text(encoding="utf-8")
    cleaned = "\n".join(ids) + "\n"
    if raw != cleaned:
        path.write_text(cleaned, encoding="utf-8")
        print(color(f"Empty lines were removed from '{path}'.", "yellow"))


# ---------------------------------------------------------------------------
# Scheduler detection and submission
# ---------------------------------------------------------------------------

@dataclass
class Scheduler:
    name: str
    submit_cmd: List[str]
    array_env_var: str
    array_flag_template: str  # formatted with {n}

    def array_flag(self, n: int) -> str:
        return self.array_flag_template.format(n=n)


SCHEDULERS = {
    "slurm": Scheduler(
        name="slurm",
        submit_cmd=["sbatch"],
        array_env_var="SLURM_ARRAY_TASK_ID",
        array_flag_template="--array=1-{n}",
    ),
    "pbs": Scheduler(
        name="pbs",
        submit_cmd=["qsub"],
        # PBSPro uses PBS_ARRAY_INDEX, Torque uses PBS_ARRAYID; the worker
        # checks both.
        array_env_var="PBS_ARRAY_INDEX",
        array_flag_template="-J 1-{n}",
    ),
    "sge": Scheduler(
        name="sge",
        submit_cmd=["qsub"],
        array_env_var="SGE_TASK_ID",
        array_flag_template="-t 1-{n}",
    ),
    "lsf": Scheduler(
        name="lsf",
        submit_cmd=["bsub"],
        array_env_var="LSB_JOBINDEX",
        array_flag_template='-J "bvbrc[1-{n}]"',
    ),
}


def detect_scheduler() -> Optional[Scheduler]:
    """Return the most likely scheduler, or None for local execution."""
    if shutil.which("sbatch"):
        return SCHEDULERS["slurm"]
    if shutil.which("bsub"):
        return SCHEDULERS["lsf"]
    if shutil.which("qsub"):
        # PBS vs SGE share the qsub binary; differentiate by env / siblings.
        if os.environ.get("SGE_ROOT") or shutil.which("qhost"):
            return SCHEDULERS["sge"]
        if (os.environ.get("PBS_HOME") or shutil.which("pbsnodes")
                or shutil.which("qstat")):
            return SCHEDULERS["pbs"]
        # Default qsub to PBS — most common HPC variant today.
        return SCHEDULERS["pbs"]
    return None


def resolve_scheduler(args: argparse.Namespace) -> Optional[Scheduler]:
    if args.force_local or args.scheduler == "local":
        return None
    if args.scheduler == "auto":
        return detect_scheduler()
    return SCHEDULERS[args.scheduler]


# ---------------------------------------------------------------------------
# Download primitives
# ---------------------------------------------------------------------------

FTPS_BASE = "ftps://ftp.bvbrc.org/genomes"


def genome_urls(genome_id: str, file_type: str) -> List[str]:
    """Candidate URLs in preferred order: HTTPS first, FTPS, plain FTP."""
    return [
        f"{HTTPS_BASE}/{genome_id}/{genome_id}.{file_type}",
        f"{FTPS_BASE}/{genome_id}/{genome_id}.{file_type}",
        f"{FTP_BASE}/{genome_id}/{genome_id}.{file_type}",
    ]


def _fetch_with_lftp(lftp: str, url: str, tmp: Path, timeout: int) -> Tuple[bool, str]:
    # BV-BRC requires explicit FTPS (AUTH TLS on port 21) with anonymous login.
    # ftps:// (implicit, port 990) is not supported by the server.
    if url.startswith("ftp://") or url.startswith("ftps://"):
        ftp_path = url.split("ftp.bvbrc.org", 1)[-1]
        cmd = (
            f"set ssl:verify-certificate false; "
            f"set ftp:ssl-auth TLS; "
            f"set ftp:ssl-force true; "
            f"set ftp:ssl-protect-data true; "
            f"set net:timeout {timeout}; "
            f"set net:max-retries 1; "
            f"open ftp://anonymous:anonymous@ftp.bvbrc.org; "
            f"user anonymous ''; "
            f"get {ftp_path} -o {tmp}; "
            f"quit"
        )
    else:
        cmd = (
            f"set ssl:verify-certificate false; "
            f"set net:timeout {timeout}; "
            f"set net:max-retries 1; "
            f"get {url} -o {tmp}; "
            f"quit"
        )
    try:
        result = subprocess.run(
            [lftp, "-c", cmd],
            capture_output=True, text=True, timeout=timeout + 30,
        )
    except subprocess.TimeoutExpired:
        tmp.unlink(missing_ok=True)
        return False, "lftp timed out"
    except OSError as exc:
        tmp.unlink(missing_ok=True)
        return False, f"lftp invocation error: {exc}"

    if result.returncode == 0 and tmp.exists() and tmp.stat().st_size > 0:
        return True, ""
    err = (result.stderr or "").strip() or f"lftp exit {result.returncode}"
    tmp.unlink(missing_ok=True)
    return False, err


def _fetch_with_wget(wget: str, url: str, tmp: Path, timeout: int) -> Tuple[bool, str]:
    try:
        result = subprocess.run(
            [wget, "-q", "--tries=1", f"--timeout={timeout}",
             "-O", str(tmp), url],
            capture_output=True, text=True, timeout=timeout + 30,
        )
    except subprocess.TimeoutExpired:
        tmp.unlink(missing_ok=True)
        return False, "wget timed out"
    except OSError as exc:
        tmp.unlink(missing_ok=True)
        return False, f"wget invocation error: {exc}"

    if result.returncode == 0 and tmp.exists() and tmp.stat().st_size > 0:
        return True, ""
    err = (result.stderr or "").strip() or f"wget exit {result.returncode}"
    tmp.unlink(missing_ok=True)
    return False, err


def _fetch_with_urllib(url: str, tmp: Path, timeout: int) -> Tuple[bool, str]:
    if not url.startswith("https://"):
        return False, "urllib only supports HTTPS"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response, \
                tmp.open("wb") as out:
            shutil.copyfileobj(response, out)
        return True, ""
    except (urllib.error.URLError, socket.timeout, OSError) as exc:
        tmp.unlink(missing_ok=True)
        return False, str(exc)


def download_one(
    genome_id: str,
    file_type: str,
    output_dir: Path,
    retries: int = 2,
    timeout: int = 120,
) -> Tuple[str, bool, str]:
    """Download one genome. Returns (id, success, message).

    Already-present files count as success (resume behavior). Each attempt
    tries every candidate URL in order before sleeping and retrying.
    Download backend priority: lftp (supports FTPS) > wget > urllib.
    """
    target = output_dir / f"{genome_id}.{file_type}"
    if target.exists() and target.stat().st_size > 0:
        return genome_id, True, "already-present"

    tmp = target.parent / (target.name + ".part")
    lftp = shutil.which("lftp")
    wget = shutil.which("wget")
    urls = genome_urls(genome_id, file_type)

    last_err = ""
    for attempt in range(retries + 1):
        for url in urls:
            if url.startswith(("ftp://", "ftps://")):
                if lftp:
                    ok, err = _fetch_with_lftp(lftp, url, tmp, timeout)
                else:
                    ok, err = False, "lftp not found; install lftp for FTPS support"
            else:
                if wget:
                    ok, err = _fetch_with_wget(wget, url, tmp, timeout)
                else:
                    ok, err = _fetch_with_urllib(url, tmp, timeout)
            if ok:
                tmp.replace(target)
                return genome_id, True, "downloaded"
            last_err = f"{url}: {err}"
        if attempt < retries:
            time.sleep(min(2 ** attempt, 10))

    tmp.unlink(missing_ok=True)
    return genome_id, False, last_err or "unknown error"


@contextmanager
def file_lock(path: Path):
    """fcntl-based exclusive append lock — works across processes on the same FS."""
    fh = path.open("a", encoding="utf-8")
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        yield fh
    finally:
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
        fh.close()


def init_report_files(report_dir: Path) -> Tuple[Path, Path]:
    downloaded = report_dir / "Downloaded_genomes.csv"
    failed = report_dir / "Failed_genomes.csv"
    downloaded.write_text("Genome ID\n", encoding="utf-8")
    failed.write_text("Genome ID\n", encoding="utf-8")
    return downloaded, failed


def report_paths(report_dir: Path) -> Tuple[Path, Path]:
    return (
        report_dir / "Downloaded_genomes.csv",
        report_dir / "Failed_genomes.csv",
    )


def append_report(path: Path, genome_id: str) -> None:
    with file_lock(path) as fh:
        fh.write(genome_id + "\n")


# ---------------------------------------------------------------------------
# Slicing
# ---------------------------------------------------------------------------

def slice_for_chunk(total: int, chunks: int, chunk_id: int) -> Tuple[int, int]:
    """1-based inclusive [start, end] for a given chunk_id (1..chunks).

    Distributes any remainder so no chunk is more than one item larger.
    """
    if chunk_id < 1 or chunk_id > chunks:
        raise ValueError(f"chunk_id {chunk_id} out of 1..{chunks}")
    base = total // chunks
    extra = total % chunks
    if chunk_id <= extra:
        size = base + 1
        start = (chunk_id - 1) * size + 1
    else:
        size = base
        start = extra * (base + 1) + (chunk_id - 1 - extra) * base + 1
    end = start + size - 1
    return start, min(end, total)


# ---------------------------------------------------------------------------
# Local execution
# ---------------------------------------------------------------------------

def run_local(args: argparse.Namespace, ids: Sequence[str]) -> int:
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    report_dir = Path(args.report_dir or PROJECT_ROOT)
    if args.report:
        downloaded_path, failed_path = init_report_files(report_dir)

    n = len(ids)
    workers = max(1, min(args.cpus, n))
    print(color(
        f"Running locally with {workers} thread(s) for {n} genome(s).", "cyan"
    ))

    succeeded = failed = 0
    start = time.time()

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(
                download_one, gid, args.file_type, output_dir,
                args.retries, args.timeout,
            ): gid
            for gid in ids
        }
        for fut in as_completed(futures):
            gid, ok, msg = fut.result()
            if ok:
                succeeded += 1
                tag = color("OK", "green")
                print(f"[{tag}] {gid}.{args.file_type} ({msg})")
                if args.report:
                    append_report(downloaded_path, gid)
            else:
                failed += 1
                tag = color("FAIL", "red")
                print(f"[{tag}] {gid}.{args.file_type}: {msg}")
                if args.report:
                    append_report(failed_path, gid)

    elapsed = time.time() - start
    print(color(
        f"Done in {elapsed:.1f}s — {succeeded} succeeded, {failed} failed.",
        "green" if failed == 0 else "yellow",
    ))
    if args.report:
        print(color(
            f"Reports: {downloaded_path}, {failed_path}", "magenta",
        ))
    return 0 if failed == 0 else 1


# ---------------------------------------------------------------------------
# Worker mode (cluster task)
# ---------------------------------------------------------------------------

def run_worker(args: argparse.Namespace, ids: Sequence[str]) -> int:
    if args.chunk_id is None or args.total_chunks is None:
        sys.exit("worker mode requires --chunk-id and --total-chunks")

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    report_dir = Path(args.report_dir or PROJECT_ROOT)

    start, end = slice_for_chunk(len(ids), args.total_chunks, args.chunk_id)
    chunk = ids[start - 1:end]
    print(f"[chunk {args.chunk_id}/{args.total_chunks}] "
          f"processing genomes {start}..{end} of {len(ids)}")

    if args.report:
        downloaded_path, failed_path = report_paths(report_dir)

    for gid in chunk:
        gid_, ok, msg = download_one(
            gid, args.file_type, output_dir, args.retries, args.timeout,
        )
        if ok:
            print(f"[OK] {gid_}.{args.file_type} ({msg})")
            if args.report:
                append_report(downloaded_path, gid_)
        else:
            print(f"[FAIL] {gid_}.{args.file_type}: {msg}")
            if args.report:
                append_report(failed_path, gid_)
    return 0


# ---------------------------------------------------------------------------
# Cluster submission
# ---------------------------------------------------------------------------

JOB_NAME = "BV_BRC_genome_downloader"


def build_slurm_script(args: argparse.Namespace, n_chunks: int,
                       log_dir: Path, worker_cmd: str) -> str:
    return textwrap.dedent(f"""\
        #!/bin/bash
        #SBATCH --job-name={JOB_NAME}
        #SBATCH --ntasks=1
        #SBATCH --cpus-per-task=1
        #SBATCH --mem={args.memory}gb
        #SBATCH --time={args.time_limit}:00:00
        #SBATCH --array=1-{n_chunks}
        #SBATCH --output={log_dir}/{JOB_NAME}_%A_%a.log
        {f'#SBATCH --mail-type=ALL' if args.mail_user else ''}
        {f'#SBATCH --mail-user={args.mail_user}' if args.mail_user else ''}

        set -euo pipefail
        TASK_ID="${{SLURM_ARRAY_TASK_ID:-1}}"
        {worker_cmd} --chunk-id "$TASK_ID" --total-chunks {n_chunks}
        """)


def build_pbs_script(args: argparse.Namespace, n_chunks: int,
                     log_dir: Path, worker_cmd: str) -> str:
    return textwrap.dedent(f"""\
        #!/bin/bash
        #PBS -N {JOB_NAME}
        #PBS -l select=1:ncpus=1:mem={args.memory}gb
        #PBS -l walltime={args.time_limit}:00:00
        #PBS -J 1-{n_chunks}
        #PBS -o {log_dir}/{JOB_NAME}_^array_index^.log
        #PBS -j oe
        {f'#PBS -M {args.mail_user}' if args.mail_user else ''}
        {f'#PBS -m abe' if args.mail_user else ''}

        set -euo pipefail
        cd "$PBS_O_WORKDIR"
        TASK_ID="${{PBS_ARRAY_INDEX:-${{PBS_ARRAYID:-1}}}}"
        {worker_cmd} --chunk-id "$TASK_ID" --total-chunks {n_chunks}
        """)


def build_sge_script(args: argparse.Namespace, n_chunks: int,
                     log_dir: Path, worker_cmd: str) -> str:
    return textwrap.dedent(f"""\
        #!/bin/bash
        #$ -N {JOB_NAME}
        #$ -cwd
        #$ -l h_vmem={args.memory}G
        #$ -l h_rt={args.time_limit}:00:00
        #$ -t 1-{n_chunks}
        #$ -o {log_dir}/{JOB_NAME}_$TASK_ID.log
        #$ -j y
        {f'#$ -M {args.mail_user}' if args.mail_user else ''}
        {f'#$ -m abe' if args.mail_user else ''}

        set -euo pipefail
        TASK_ID="${{SGE_TASK_ID:-1}}"
        {worker_cmd} --chunk-id "$TASK_ID" --total-chunks {n_chunks}
        """)


def build_lsf_script(args: argparse.Namespace, n_chunks: int,
                     log_dir: Path, worker_cmd: str) -> str:
    return textwrap.dedent(f"""\
        #!/bin/bash
        #BSUB -J "{JOB_NAME}[1-{n_chunks}]"
        #BSUB -n 1
        #BSUB -M {args.memory * 1024}
        #BSUB -W {args.time_limit}:00
        #BSUB -o {log_dir}/{JOB_NAME}_%J_%I.log
        {f'#BSUB -u {args.mail_user}' if args.mail_user else ''}
        {f'#BSUB -N' if args.mail_user else ''}

        set -euo pipefail
        TASK_ID="${{LSB_JOBINDEX:-1}}"
        {worker_cmd} --chunk-id "$TASK_ID" --total-chunks {n_chunks}
        """)


SCRIPT_BUILDERS = {
    "slurm": build_slurm_script,
    "pbs": build_pbs_script,
    "sge": build_sge_script,
    "lsf": build_lsf_script,
}


def build_worker_cmd(args: argparse.Namespace, report_dir: Path) -> str:
    """Re-invoke this script in --worker mode with the same parameters."""
    parts = [
        f'"{sys.executable}"',
        f'"{Path(__file__).resolve()}"',
        "--worker",
        "-i", f'"{Path(args.input_file).resolve()}"',
        "-o", f'"{Path(args.output_dir).resolve()}"',
        "-f", args.file_type,
        "--retries", str(args.retries),
        "--timeout", str(args.timeout),
        "--report-dir", f'"{report_dir}"',
    ]
    if args.report:
        parts.append("--report")
    return " ".join(parts)


def submit_cluster(args: argparse.Namespace, scheduler: Scheduler,
                   ids: Sequence[str]) -> int:
    temp_dir = Path(args.temp_dir).resolve()
    temp_dir.mkdir(parents=True, exist_ok=True)
    log_dir = temp_dir / f"logs_{JOB_NAME}"
    if args.logs:
        log_dir.mkdir(parents=True, exist_ok=True)
    else:
        # Still need a directory the scheduler can write to.
        log_dir.mkdir(parents=True, exist_ok=True)

    n_chunks = max(1, min(args.cpus, len(ids)))
    if n_chunks < args.cpus:
        print(color(
            f"Note: capped tasks at {n_chunks} (one per genome).", "yellow",
        ))

    report_dir = PROJECT_ROOT
    if args.report:
        init_report_files(report_dir)

    worker_cmd = build_worker_cmd(args, report_dir)
    builder = SCRIPT_BUILDERS[scheduler.name]
    script_text = builder(args, n_chunks, log_dir, worker_cmd)

    script_path = temp_dir / f"{JOB_NAME}_{scheduler.name}.sh"
    script_path.write_text(script_text, encoding="utf-8")
    script_path.chmod(0o755)

    print(color(f"Detected scheduler: {scheduler.name}", "cyan"))
    print(color(f"Submit script:    {script_path}", "cyan"))
    print(color(f"Array tasks:      {n_chunks}", "cyan"))
    print(color(f"Genomes:          {len(ids)}", "cyan"))
    if args.logs:
        print(color(f"Logs:             {log_dir}", "cyan"))

    submit = list(scheduler.submit_cmd) + [str(script_path)]
    if scheduler.name == "lsf":
        # LSF reads directives from stdin.
        result = subprocess.run(
            scheduler.submit_cmd, input=script_text, text=True, capture_output=True,
        )
    else:
        result = subprocess.run(submit, text=True, capture_output=True)

    if result.returncode != 0:
        sys.stderr.write(color(
            f"Submission failed (exit {result.returncode}):\n{result.stderr}",
            "red",
        ) + "\n")
        return result.returncode

    sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    print(color(f"{JOB_NAME} submitted.", "green"))
    return 0


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: Optional[Sequence[str]] = None) -> int:
    raw = list(sys.argv[1:] if argv is None else argv)
    parser = build_parser()
    args = parser.parse_args(_normalize_argv(raw))

    if args.worker:
        # Workers don't re-validate scheduler args; they just need i/o/f.
        if not (args.input_file and args.output_dir and args.file_type):
            parser.error("worker mode requires -i, -o, and -f")
        ids = read_genome_ids(Path(args.input_file))
        return run_worker(args, ids)

    validate_args(args, parser)
    print(f"host: {socket.gethostname()}")
    print(f"cwd:  {os.getcwd()}")

    input_path = Path(args.input_file).resolve()
    ids = read_genome_ids(input_path)
    write_clean_input(input_path, ids)
    print(f"genomes to download: {len(ids)}")

    scheduler = resolve_scheduler(args)
    if scheduler is None:
        return run_local(args, ids)
    return submit_cluster(args, scheduler, ids)


if __name__ == "__main__":
    sys.exit(main())
