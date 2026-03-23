# S-Matrix Bootstrap via Semidefinite Programming

Numerical bounds on scattering amplitudes and form factors in 2D quantum field theory, obtained by casting physical consistency conditions (unitarity, crossing symmetry, analyticity) as a semidefinite program (SDP) and solving it with [SDPB](https://github.com/davidsd/sdpb).

This repository contains the code used to produce the results in:

- M. Correia, J. Penedones, A. Vuignier — *Injecting the UV into the Bootstrap: Ising Field Theory*, [arXiv:2212.03917](https://arxiv.org/abs/2212.03917)
- L. Córdova, M. Correia, A. Georgoudis, A. Vuignier — *The O(N) Monolith reloaded: Sum rules and Form Factor Bootstrap*, [arXiv:2311.03031](https://arxiv.org/abs/2311.03031)

---

## What this project does

We want to answer: *given only fundamental physical principles, what scattering processes are mathematically possible?*

The approach reformulates this as a **convex optimization problem**:

1. **Decision variables**: coefficients of a spectral decomposition of the scattering amplitude, expanded in a basis of conformal-map variables (ρ, τ).
2. **Constraints**: positive-semidefiniteness of matrices encoding unitarity at hundreds of kinematic sample points, plus linear relations from crossing symmetry and analyticity.
3. **Objective**: maximize or minimize a physical observable (e.g. a coupling constant) to find the boundary of the allowed region.

This is a standard **semidefinite program** (SDP), solved using the specialized solver SDPB on an HPC cluster.

---

## Pipeline

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  1. FORMULATE    │     │  2. CONVERT      │     │  3. SOLVE        │     │  4. ANALYZE      │
│                  │     │                  │     │                  │     │                  │
│  Mathematica     │────▶│  sdp2input       │────▶│  SDPB (MPI)     │────▶│  Mathematica     │
│                  │     │                  │     │                  │     │                  │
│  Build ansatz,   │     │  Serialize SDP   │     │  Interior-point  │     │  Reconstruct     │
│  impose PSD      │     │  to binary       │     │  method on HPC   │     │  amplitudes,     │
│  constraints     │     │  format          │     │  cluster         │     │  plot bounds     │
└──────────────────┘     └──────────────────┘     └──────────────────┘     └──────────────────┘
     .m file                  SDPB input              y.txt, out.txt           figures
```

The Python scripts orchestrate the full chain: calling Mathematica to build the problem, converting formats, launching the solver, and collecting results.

---

## Repository structure

```
├── mathematica/
│   ├── util.m                  # Kinematics, conformal variables (ρ, τ), grids
│   ├── convertor.m             # Complex → real matrix conversion for SDPB
│   └── bootstrap_problem.m     # SDP construction: ansatz, constraints, objective
│
├── scripts/
│   ├── run_local.py            # Run full pipeline locally (via Docker)
│   ├── run_cluster.py          # Run full pipeline on a SLURM cluster node
│   └── submit_jobs.py          # Batch-submit parameter scans to SLURM
│
├── notebooks/
│   └── plots.nb                # Mathematica notebook: read SDPB output, plot bounds
│
├── config.py                   # Paths, precision, solver parameters
├── .gitignore
└── README.md
```

---

## Key implementation details

### Spectral decomposition (Mathematica)

The S-matrix amplitude is expanded in a basis adapted to its analytic structure. The conformal-mapping variable

$$\rho(s) = \frac{\sqrt{4m^2 - s_0} - \sqrt{4m^2 - s}}{\sqrt{4m^2 - s_0} + \sqrt{4m^2 - s}}$$

maps the cut complex plane onto the unit disk, making the expansion rapidly convergent. A similar τ-variable handles crossed-channel contributions. Truncation at order `maxN` controls the approximation quality.

### SDP formulation

At each of 350 Chebyshev-distributed sample points in the physical region, unitarity is imposed as a positive-semidefinite constraint:

$$M(s_i) \succeq 0, \quad i = 1, \dots, N$$

where M(s) is a matrix built from partial-wave amplitudes. Together with integral constraints from crossing symmetry, this defines an SDP with ~100 decision variables and ~350 matrix constraints.

### Solver orchestration (Python)

The Python layer handles:
- Calling `wolframscript` to construct the `.m` problem file
- Converting to SDPB's format via `sdp2input`
- Launching SDPB with MPI (locally via Docker, or on a SLURM cluster)
- File management and parameter scans

---

## Usage

### Prerequisites

- [Wolfram Mathematica](https://www.wolfram.com/mathematica/) (or `wolframscript`)
- [SDPB](https://github.com/davidsd/sdpb) — via Docker (`wlandry/sdpb:2.4.0`) or compiled on your cluster
- Python 3.6+

### Run locally (Docker)

```bash
# 1. Edit config.py to set your working directory and number of cores
# 2. Run:
python scripts/run_local.py
```

### Run on a SLURM cluster

```bash
# 1. Edit config.py for cluster paths and SLURM settings
# 2. Submit a parameter scan:
python scripts/submit_jobs.py
```

### Analyze results

Open `notebooks/plots.nb` in Mathematica. It reads the SDPB output directories, reconstructs the optimal amplitudes from the dual variables, and produces the bound plots (e.g. Figure 20 in [arXiv:2212.03917](https://arxiv.org/abs/2212.03917)).

---

## Sample results

**Lower bound on the UV central charge** (Figure 2 from [arXiv:2212.03917](https://arxiv.org/abs/2212.03917)): for ℤ₂-symmetric QFTs with a single stable particle, the minimum central charge interpolates between the free boson (c = 1) and the free fermion (c = 1/2) as a function of the quartic coupling Λ.

<p align="center">
  <img src="figures/cuv_bound.png" width="500"/>
</p>

**Allowed region for Ising Field Theory** (Figure 20 from [arXiv:2212.03917](https://arxiv.org/abs/2212.03917)): fixing the UV central charge to c = 1/2 and imposing a zero in the S-matrix at x = 1/10, the bootstrap carves out the allowed region in the (gF₁, g²) plane. The dashed lines show perturbation theory.

<p align="center">
  <img src="figures/ift_allowed_region.png" width="500"/>
</p>

---


## References

1. M. Correia, J. Penedones, A. Vuignier — *Injecting the UV into the Bootstrap: Ising Field Theory*, [arXiv:2212.03917](https://arxiv.org/abs/2212.03917)
2. L. Córdova, M. Correia, A. Georgoudis, A. Vuignier — *The O(N) Monolith reloaded*, [arXiv:2311.03031](https://arxiv.org/abs/2311.03031)
3. D. Simmons-Duffin — [SDPB: A Semidefinite Program Solver](https://github.com/davidsd/sdpb)
