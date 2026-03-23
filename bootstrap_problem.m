(* ::Package:: *)
(* ================================================================
   bootstrap_problem.m — Construct the SDP for the S-matrix bootstrap
   
   Given truncation order maxN, a kinematic parameter x, and a 
   coupling gF, this module:
   
   1. Builds an ansatz for the partial-wave amplitudes (lambda1, W_T, W_F)
      using conformal-map basis functions.
   2. Assembles the unitarity constraint matrices M(si) >= 0 at 
      each sample point.
   3. Adds crossing-symmetry integral constraints.
   4. Packages everything as an SDP[objective, normalization, matrices]
      and exports it for SDPB.
   
   Usage (from wolframscript):
     Get["bootstrap_problem.m"];
     constructProblem[maxN][xParam][gF]
   ================================================================ *)


(* ---------- load dependencies ---------- *)
currentDirectory = If[$InputFileName == "",
    NotebookDirectory[],
    $InputFileName // DirectoryName
];
FileNameJoin[{currentDirectory, "util.m"}] // Get;
FileNameJoin[{currentDirectory, "convertor.m"}] // Get;


(* ---------- output directory ---------- *)
directoryProblemsSolutions = Environment["BOOTSTRAP_WORK_DIR"];
If[directoryProblemsSolutions === $Failed,
    directoryProblemsSolutions = FileNameJoin[{$HomeDirectory, "bootstrap", "smatrix"}]
];


(* ================================================================
   constructAnsatz — build basis functions and their integrals
   
   Returns {ansatzLambda1, ansatzWT, ansatzWF, objectiveVector}
   ================================================================ *)

constructAnsatz[maxN_][xValue2_][gF_] := Module[
    {ansatzLambda1, ansatzWT, ansatzWF, objectR,
     integratedImWF, integratedN2ReWT, integratedImWT, integratedlambda1,
     intpole, xValue},

    xValue = xValue2 / 10000;

    ansatzLambda1 = 
        Table[Sqrt[s - 4] (tau[s, 0]^n + Conjugate[tau[s, 0]^n]) / (s (s - 4)), {n, 0, 1}]
        ~Join~
        Table[Sqrt[s - 4] I (tau[s, 0]^n - Conjugate[tau[s, 0]^n]) / (s (s - 4)), {n, 1, maxN}]
        ~Join~
        Table[I (tau[s, 0]^n - Conjugate[tau[s, 0]^n]) / (s^2), {n, 1, 10}];

    integratedlambda1 = 
        {\[Pi], 0}
        ~Join~ Table[-1/n + (-1)^n 1/n, {n, 1, maxN}]
        ~Join~ Table[integratedSpectralDensityB[n], {n, 1, 10}];

    ansatzWT = 
        {(s - 2) / (s (4 - s)) 1/(s - 3 - xValue) 1/(s - 1 + xValue)}
        ~Join~
        Table[1/(s (4 - s)) (tau[s, 2]^n - taucross[s, 2]^n), {n, 1, maxN}];

    intpole[x_] := -2 (ArcSec[2/Sqrt[1 - x]] + ArcSec[2/Sqrt[3 + x]]) / Sqrt[(1 - x) (3 + x)];
    integratedN2ReWT = {intpole[xValue]} ~Join~ Table[0, {n, 1, maxN}] // N[#, prec] &;
    integratedImWT   = {\[Pi]/2 1/(1 - xValue) 1/(3 + xValue)} ~Join~ Table[0, {n, 1, maxN}];

    ansatzWF = 
        {1} ~Join~ Table[tau[s, 0]^n / (s - 4) - (-1)^n / s, {n, 0, maxN}];

    integratedImWF = {0} ~Join~ Table[-(-1)^n \[Pi], {n, 0, maxN}];

    objectR = 
        (2 * integratedlambda1)
        ~Join~
        Table[-I N2[1 - xValue] integratedImWT[[n]] + integratedN2ReWT[[n]],
              {n, 1, ansatzWT // Length}]
        ~Join~
        (2 * integratedImWF)
        ~Join~
        {-0.5, -gF} // N[#, prec] &;

    {ansatzLambda1, ansatzWT, ansatzWF, objectR}
];


(* ================================================================
   constructProblem — assemble and export the full SDP
   ================================================================ *)

constructProblem[maxN_][xValue_][gF_] := Module[
    {input, ansatzLambda1, ansatzWT, ansatzWF, objectR,
     matrixLambda13x3, matrixWT3x3, matrixWF3x3, matrixX3x3,
     matrixZero3x3, matrixZero2x2, matrixAd,
     matrix, matrices, normalization, objective, parameters,
     hash, name, nameRaw},

    input = constructAnsatz[maxN][xValue][gF];
    ansatzLambda1 = input[[1]];
    ansatzWT      = input[[2]];
    ansatzWF      = input[[3]];
    objectR       = input[[4]];

    (* --- 3x3 unitarity matrices for each basis function --- *)
    matrixLambda13x3 = Table[
        {{ansatzLambda1[[n]], 0, 0},
         {0, ansatzLambda1[[n]], 0},
         {0, 0, 0}},
        {n, 1, ansatzLambda1 // Length}];

    matrixWT3x3 = Table[
        {{0, N2[s]*ansatzWT[[n]]/2, 0},
         {Conjugate[N2[s]*ansatzWT[[n]]/2], 0, 0},
         {0, 0, 0}},
        {n, 1, ansatzWT // Length}];

    matrixWF3x3 = (I Sqrt[N2[s]]/4) Table[
        {{0, 0, ansatzWF[[n]]},
         {0, 0, -Conjugate[ansatzWF[[n]]]},
         {-Conjugate[ansatzWF[[n]]], ansatzWF[[n]], 0}},
        {n, 1, ansatzWF // Length}];

    matrixX3x3 = {{{0, 0, 0}, {0, 0, 0}, {0, 0, -6/(s^2)}}};

    matrixZero2x2 = {{0, 0}, {0, 0}};
    matrixZero3x3 = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}};

    (* --- full constraint: evaluate at each sample point --- *)
    matrix = {matrixZero3x3}
        ~Join~ matrixLambda13x3
        ~Join~ matrixWT3x3
        ~Join~ matrixWF3x3
        ~Join~ matrixX3x3
        ~Join~ {matrixZero3x3};

    matrixAd = {{{0, 0}, {0, 48 \[Pi]}}}
        ~Join~ Table[matrixZero2x2, Length[ansatzLambda1]]
        ~Join~ Table[{{0, 0}, {0, 48 \[Pi]^2 ansatzWT[[n]] /. s -> 1}},
                     {n, 1, ansatzWT // Length}]
        ~Join~ Table[{{0, \[Pi] ansatzWF[[n]] /. s -> 1},
                      {\[Pi] ansatzWF[[n]] /. s -> 1, 0}},
                     {n, 1, ansatzWF // Length}]
        ~Join~ {{{1, 0}, {0, 0}}}
        ~Join~ {{{0, 1}, {1, 0}}};

    matrices = {matrixAd}
        ~Join~ Table[matrix /. s -> points[[i]], {i, 1, points // Length}]
        // N[#, prec] &
        // convert;

    normalization = Table[If[i == 1, +1, 0], {i, 1, matrix // Length}];
    objective     = {0} ~Join~ objectR // N[#, prec] &;

    parameters = {maxN, xValue, gF, points // Length};
    hash = Hash[parameters] // ToString;

    (* Export description (for identifying results later) *)
    name = FileNameJoin[{directoryProblemsSolutions, "problems", "description_" <> hash <> ".wl"}];
    Export[name, parameters];

    (* Export SDP problem file *)
    nameRaw = "problem_" <> hash <> ".m";
    name = FileNameJoin[{directoryProblemsSolutions, "problems", nameRaw}];
    Export[name, SDP[objective, normalization, matrices]];

    Write["stdout", "SDPB input file:"];
    Write["stdout", nameRaw];
];
