(* ::Package:: *)
(* ================================================================
   util.m — Kinematics, conformal variables, and grid definitions
   
   Defines the expansion variables (rho, tau) that map the cut 
   s-plane onto the unit disk, making the spectral decomposition 
   rapidly convergent. Also provides Chebyshev grids for sampling
   the physical region.
   ================================================================ *)


(* ---------- working precision ---------- *)
prec = 150;
highPrecision[expr_] := SetPrecision[expr, prec];


(* ---------- mass ---------- *)
m = 1;


(* ---------- two-body phase space factor ---------- *)
N2[s_]  := 2 Sqrt[s] Sqrt[s - 4 m^2];
N2i[s_] := 2 I Sqrt[s] Sqrt[4 m^2 - s];


(* ---------- Chebyshev grid ---------- *)
(* Distributes n points in [a, b] at Chebyshev nodes.
   Concentrates points near endpoints — good for polynomial 
   interpolation and for sampling functions with edge effects. *)
chebyshevGrid[n_][a_, b_] := (a + b)/2 + (b - a)/2 Table[
    Cos[(2 k - 1)/(2 n) \[Pi]], {k, n, 1, -1}
];


(* ---------- rho variable (conformal map for s-channel) ---------- *)
(* Maps the s-plane cut along [4m^2, ∞) onto the unit disk.
   The expansion  Σ c_n ρ^n  converges geometrically. *)
rhoOriginal = (Sqrt[4 msq - s0] - Sqrt[4 msq - s]) / (Sqrt[4 msq - s0] + Sqrt[4 msq - s]);
rho         = rhoOriginal /. Sqrt[4 msq - s] -> -I Sqrt[s - 4 msq] /. msq -> m^2;
rhoCrossed  = rhoOriginal /. s -> 4 msq - s /. msq -> m^2;


(* ---------- tau variable (conformal map with threshold q) ---------- *)
tauOriginal[s_, q_] = (Sqrt[4 - q] - Sqrt[4 - s]) / (Sqrt[4 - q] + Sqrt[4 - s]);
tau[s_, q_]         = (Sqrt[4 - q] + I*Sqrt[s - 4]) / (Sqrt[4 - q] - I*Sqrt[s - 4]);
taucross[s_, q_]    = (Sqrt[4 - q] - Sqrt[s]) / (Sqrt[4 - q] + Sqrt[s]);


(* ---------- spectral density basis functions ---------- *)
(* Real (A) and imaginary (B) parts of ρ^n, evaluated at s0 = 0. *)
spectralDensityA[n_] := rho^n + Conjugate[rho^n] /. s0 -> 0;
spectralDensityB[n_] := I (rho^n - Conjugate[rho^n]) /. s0 -> 0;


(* ---------- integrated spectral density ---------- *)
(* Analytic results for ∫_{4}^{∞} ρ^n / s^2 ds *)
int[0] := 1/4;
int[1] := (I \[Pi])/16;
int[n_] := -((1 + (-1)^n) / (8 (-1 + n^2)));
integratedSpectralDensityA[n_] := int[n] + Conjugate[int[n]];
integratedSpectralDensityB[n_] := I (int[n] - Conjugate[int[n]]);


(* ---------- protected symbols ---------- *)
Protect[gsq, a, x, msq, s0];


(* ---------- unitarity sample points ---------- *)
(* 350 Chebyshev points mapped from [0, π] into [4m^2, ∞)
   via s = 8 / (1 + cos φ). This clusters points near 
   threshold (s = 4) where unitarity is most constraining. *)
numberPoints = 350;
samplePhi    = chebyshevGrid[numberPoints][0, \[Pi]];
points       = Table[8 / (1 + Cos[\[Phi]]), {\[Phi], samplePhi}] // N[#, prec] &;
