#!/usr/bin/env python3
"""
Run the full bootstrap pipeline on a SLURM cluster.

This script is meant to be called from within a SLURM job (see submit_jobs.py).
It expects three command-line arguments: maxN, xParam, gFparam.

Pipeline:
  1. wolframscript → problem_<hash>.m
  2. sdp2input     → problem_<hash>_in/
  3. sdpb          → problem_<hash>_out/ (contains y.txt, out.txt)

Usage:
    python scripts/run_cluster.py <maxN> <xParam> <gFparam>
"""

import os
import sys
import subprocess
import shlex

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import config


def main():
    maxN    = sys.argv[1]
    x_param = sys.argv[2]
    gf_param = sys.argv[3]

    print(f"\n{'='*50}", flush=True)
    print(f"  maxN={maxN}  x={x_param}  gF={gf_param}", flush=True)
    print(f"{'='*50}\n", flush=True)

    script_dir = os.path.dirname(os.path.realpath(__file__))
    math_file  = os.path.join(script_dir, "..", "mathematica", "bootstrap_problem.m")
    problem_dir = os.path.join(config.WORK_DIR, "problems")

    # Paths to SDPB binaries (assumed to be on the cluster PATH or in bin/)
    sdp2input_bin = os.environ.get("SDP2INPUT_BIN", "sdp2input")
    sdpb_bin      = os.environ.get("SDPB_BIN", "sdpb")

    # --- Step 1: construct .m file via Mathematica ---
    code = f'Get["{math_file}"]; constructProblem[{maxN}][{x_param}][{gf_param}]'
    result = subprocess.run(
        ["wolframscript", "-code", code],
        capture_output=True, text=True
    )
    lines = [l.strip() for l in result.stdout.strip().split("\n") if l.strip()]
    for line in lines:
        print(line, flush=True)

    m_name = sorted(lines)[-1]
    m_path = os.path.join(problem_dir, m_name)
    print(f"\nMathematica file: {m_path}", flush=True)

    # --- Step 2: convert to SDPB input ---
    in_path  = m_path
    out_path = m_path[:-2] + "_in"
    cmd = (
        f"srun {sdp2input_bin} "
        f"--precision={config.BINARY_PRECISION} "
        f"--input={in_path} --output={out_path}"
    )
    print(f"\nConverting: {cmd}", flush=True)
    subprocess.run(shlex.split(cmd), check=True)
    print(f"Converted: {out_path}", flush=True)

    # --- Step 3: solve with SDPB ---
    sdpb_out = out_path[:-3] + "_out"
    cmd = (
        f"srun {sdpb_bin} "
        f"--procsPerNode={config.SLURM_TASKS_PER_NODE} "
        f"--writeSolution y "
        f"--maxIterations {config.MAX_ITERATIONS} "
        f"--initialMatrixScalePrimal {config.INITIAL_MATRIX_SCALE_PRIMAL} "
        f"--initialMatrixScaleDual {config.INITIAL_MATRIX_SCALE_DUAL} "
        f"--maxComplementarity {config.MAX_COMPLEMENTARITY} "
        f"--dualityGapThreshold {config.DUALITY_GAP_THRESHOLD} "
        f"--precision {config.BINARY_PRECISION} "
        f"-s {out_path} -o {sdpb_out}"
    )
    print(f"\nSolving: {cmd}", flush=True)
    subprocess.run(shlex.split(cmd), check=True)

    # --- Step 4: move description file into output directory ---
    hash_str = sdpb_out.split("_")[-2]  # extract hash
    desc_src = os.path.join(problem_dir, f"description_{hash_str}.wl")
    desc_dst = os.path.join(sdpb_out, "description.wl")
    if os.path.exists(desc_src):
        os.rename(desc_src, desc_dst)

    print(f"\nDone. Output: {sdpb_out}", flush=True)


if __name__ == "__main__":
    main()
