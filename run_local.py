#!/usr/bin/env python3
"""
Run the full bootstrap pipeline locally using Docker.

For each (maxN, xParam, gF) problem:
  1. Call Mathematica to construct the SDP problem file (.m)
  2. Convert to SDPB binary format via sdp2input (inside Docker)
  3. Solve with SDPB (inside Docker)
  4. Collect output files

Usage:
    python scripts/run_local.py
"""

import os
import subprocess
import shlex
import sys

# Add project root to path so we can import config
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import config


# ---------------------------------------------------------------------------
# Problem list: each entry is [maxN, xParam, gF]
#
# maxN   — truncation order of the spectral decomposition
# xParam — kinematic parameter (divided by 10000 internally)
# gF     — coupling constant value to probe
# ---------------------------------------------------------------------------
PROBLEMS = [
    [20, 1000, 0.0],
]


def run_mathematica(maxN, x_param, gf_param):
    """Call wolframscript to construct the .m problem file."""
    math_file = os.path.join(config.MATHEMATICA_DIR, "bootstrap_problem.m")
    code = f'Get["{math_file}"]; constructProblem[{maxN}][{x_param}][{gf_param}]'

    result = subprocess.run(
        ["wolframscript", "-code", code],
        capture_output=True, text=True
    )
    # The last non-empty line of stdout is the problem filename
    lines = [l.strip() for l in result.stdout.strip().split("\n") if l.strip()]
    filename = sorted(lines)[-1]
    print(f"  Mathematica file constructed: {filename}")
    return filename


def run_sdp2input(problem_file):
    """Convert the .m file to SDPB's binary format using Docker."""
    out_dir = problem_file[:-2]  # strip .m extension
    docker_cmd = (
        f"docker run -v {config.WORK_DIR}:/usr/local/share/sdpb/ "
        f"{config.DOCKER_IMAGE} "
        f"mpirun --allow-run-as-root -n {config.LOCAL_NUM_CORES} "
        f"sdp2input --precision={config.BINARY_PRECISION} "
        f"--input=/usr/local/share/sdpb/{problem_file} "
        f"--output=/usr/local/share/sdpb/{out_dir}"
    )
    subprocess.run(shlex.split(docker_cmd), check=True)
    print(f"  SDPB input constructed: {out_dir}")
    return out_dir


def run_sdpb(sdp_input_dir):
    """Solve the SDP using SDPB inside Docker."""
    out_dir = sdp_input_dir[:-3] + "_out"  # replace _in with _out
    n = config.LOCAL_NUM_CORES
    docker_cmd = (
        f"docker run -v {config.WORK_DIR}:/usr/local/share/sdpb/ "
        f"{config.DOCKER_IMAGE} "
        f"mpirun --allow-run-as-root -n {n} sdpb "
        f"--procsPerNode={n} "
        f"--precision={config.BINARY_PRECISION} "
        f"--writeSolution y "
        f"--maxIterations {config.MAX_ITERATIONS} "
        f"--maxComplementarity {config.MAX_COMPLEMENTARITY} "
        f"--dualityGapThreshold {config.DUALITY_GAP_THRESHOLD} "
        f"--noFinalCheckpoint "
        f"-s /usr/local/share/sdpb/{sdp_input_dir}"
    )
    subprocess.run(shlex.split(docker_cmd), check=True)
    print(f"  SDPB solved: {out_dir}")
    return out_dir


def move_description(problem_file, output_dir):
    """Move the description file into the output directory for easy lookup."""
    hash_str = problem_file[8:-2]  # extract hash from "problem_<hash>.m"
    src = os.path.join(config.WORK_DIR, f"description_{hash_str}.wl")
    dst = os.path.join(config.WORK_DIR, output_dir, "description.wl")
    if os.path.exists(src):
        os.rename(src, dst)


def cleanup(problem_file, sdp_input_dir):
    """Remove intermediate files (keep only the output directory)."""
    for path in [problem_file, sdp_input_dir, sdp_input_dir.replace("_in", ".ck")]:
        full = os.path.join(config.WORK_DIR, path)
        if os.path.isdir(full):
            subprocess.run(["rm", "-r", full])
        elif os.path.isfile(full):
            os.remove(full)


def main():
    for maxN, x_param, gf_param in PROBLEMS:
        print(f"\n{'='*60}")
        print(f"  maxN={maxN}  x={x_param}  gF={gf_param}")
        print(f"{'='*60}")

        problem_file = run_mathematica(maxN, x_param, gf_param)
        sdp_input = run_sdp2input(problem_file)
        output_dir = run_sdpb(sdp_input)
        move_description(problem_file, output_dir)
        cleanup(problem_file, sdp_input)

        print(f"  Done. Results in: {output_dir}/")


if __name__ == "__main__":
    main()
