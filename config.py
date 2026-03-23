"""
Configuration for the S-matrix bootstrap pipeline.

Edit this file to match your environment before running any scripts.
"""

import os

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# Root directory where problem files and SDPB output are stored.
# Local mode:  an absolute path on your machine (must match the Docker volume mount).
# Cluster mode: a path on the shared filesystem visible to all nodes.
WORK_DIR = os.environ.get(
    "BOOTSTRAP_WORK_DIR",
    os.path.expanduser("~/bootstrap/smatrix/")
)

# Directory containing the Mathematica source files (util.m, convertor.m, bootstrap_problem.m).
MATHEMATICA_DIR = os.path.join(os.path.dirname(__file__), "mathematica")

# ---------------------------------------------------------------------------
# Solver settings
# ---------------------------------------------------------------------------

# Arithmetic precision in bits (SDPB uses arbitrary-precision arithmetic).
BINARY_PRECISION = 700

# Stop when the duality gap drops below this threshold.
DUALITY_GAP_THRESHOLD = "1e-8"

# Maximum number of interior-point iterations.
MAX_ITERATIONS = 700

# SDPB tuning (see SDPB docs for details).
INITIAL_MATRIX_SCALE_PRIMAL = "1e20"
INITIAL_MATRIX_SCALE_DUAL   = "1e20"
MAX_COMPLEMENTARITY         = "1e50"

# ---------------------------------------------------------------------------
# Execution settings
# ---------------------------------------------------------------------------

# Local execution (Docker).
DOCKER_IMAGE   = "wlandry/sdpb:2.4.0"
LOCAL_NUM_CORES = 3

# Cluster execution (SLURM).
SLURM_NODES             = 1
SLURM_TASKS_PER_NODE    = 36
SLURM_TIME_LIMIT        = "01:00:00"
SLURM_ACCOUNT           = "fsl"
SLURM_MODULES           = ["gcc/8.4.0", "mvapich2/2.3.4", "mathematica/11.1.1", "python", "boost"]
