#!/usr/bin/env python3
"""
Batch-submit SLURM jobs for a parameter scan.

Each entry in PROBLEMS generates one SLURM job that runs the full pipeline
(Mathematica → sdp2input → SDPB) via run_cluster.py.

Usage:
    python scripts/submit_jobs.py
"""

import os
import subprocess
import uuid
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import config


# ---------------------------------------------------------------------------
# Parameter scan: [maxN, xParam, gFparam]
# ---------------------------------------------------------------------------
PROBLEMS = [
    [50, 1000, -0.01192],
    [50, 1000, -0.005],
    [50, 1000,  0.0],
    [50, 1000,  0.002],
    [50, 1000,  0.0055842],
]


# SLURM job template
SBATCH_TEMPLATE = """\
#!/bin/bash
#SBATCH --chdir {work_dir}
#SBATCH --nodes {nodes}
#SBATCH --ntasks-per-node={tasks_per_node}
#SBATCH --mem 0
#SBATCH --time {time_limit}
#SBATCH --account {account}

echo "Job started: $(date)"
{module_loads}
echo "Tasks: $SLURM_NTASKS"

{command}

echo "Job finished: $(date)"
"""


def main():
    script_dir  = os.path.dirname(os.path.realpath(__file__))
    cluster_py  = os.path.join(script_dir, "run_cluster.py")
    problem_dir = os.path.join(config.WORK_DIR, "problems")
    sbatch_dir  = os.path.join(config.WORK_DIR, "sbatch")

    os.makedirs(problem_dir, exist_ok=True)
    os.makedirs(sbatch_dir, exist_ok=True)

    module_lines = "\n".join(f"module load {m}" for m in config.SLURM_MODULES)

    for maxN, x_param, gf_param in PROBLEMS:
        command = f"python3 {cluster_py} {maxN} {x_param} {gf_param}"

        script_content = SBATCH_TEMPLATE.format(
            work_dir=problem_dir,
            nodes=config.SLURM_NODES,
            tasks_per_node=config.SLURM_TASKS_PER_NODE,
            time_limit=config.SLURM_TIME_LIMIT,
            account=config.SLURM_ACCOUNT,
            module_loads=module_lines,
            command=command,
        )

        sbatch_file = os.path.join(sbatch_dir, f"sbatch_{uuid.uuid4()}.sh")
        with open(sbatch_file, "w") as f:
            f.write(script_content)
        os.chmod(sbatch_file, 0o755)

        print(f"Submitting: maxN={maxN}, x={x_param}, gF={gf_param}")
        subprocess.run(["sbatch", sbatch_file])


if __name__ == "__main__":
    main()
