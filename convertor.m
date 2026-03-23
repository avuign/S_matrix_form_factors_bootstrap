(* ::Package:: *)
(* ================================================================
   convertor.m — Convert complex PSD constraints to SDPB format
   
   SDPB requires real symmetric matrices. A complex Hermitian 
   constraint  H ≽ 0  is equivalent to the real constraint
   
       ┌ Re(H)  -Im(H) ┐
       │                │ ≽ 0
       └ Im(H)   Re(H) ┘
   
   This module performs that embedding and packages the result 
   in SDPB's PositiveMatrixWithPrefactor format.
   ================================================================ *)


(* ---------- complex → real embedding ---------- *)
(* Given a Hermitian matrix, return the equivalent real PSD matrix. *)
makeReal[matrix_] := Module[{re, im},
    re = matrix // Re;
    im = matrix // Im;
    ArrayFlatten[{{re, -im}, {im, re}}]
];


(* ---------- merge block-diagonal matrices ---------- *)
(* Takes a list of matrices and assembles them into a single 
   block-diagonal matrix using Flat + Listable attribute trick. *)
mergeMatrices[listMatrices_] := Module[{f, temp},
    SetAttributes[f, {Flat, Listable}];
    temp = f @@ listMatrices;
    temp /. f -> List
];


(* ---------- apply function two levels deep ---------- *)
(* For a nested list {{a1, a2, ...}, {b1, b2, ...}, ...},
   applies f to each element: {{f[a1], f[a2], ...}, ...} *)
applyTwoLevels[function_][list_] := Module[{temp = list},
    Do[
        temp[[i, j]] = list[[i, j]] // function,
        {i, 1, list // Length},
        {j, 1, list[[i]] // Length}
    ];
    temp
];


(* ---------- combined transformation ---------- *)
makeRealTranspose[expr_] := expr // makeReal // Transpose;


(* ---------- main conversion function ---------- *)
(* Takes a list of complex constraint matrices (one per sample point)
   and returns a list of PositiveMatrixWithPrefactor objects for SDPB. *)
convert[expr_] := Module[{tempA, tempB, check},

    (* Step 1: embed each complex matrix as a real matrix *)
    tempA = expr // applyTwoLevels[makeRealTranspose];

    (* Step 2: merge block structure *)
    tempB = Table[tempA[[i]] // mergeMatrices, {i, 1, tempA // Length}];

    (* Step 3: sanity check — result must be purely real *)
    check = tempB // Im // Flatten // Union;
    If[Not[check === {0}], Print["Error: the matrix is complex"]];

    (* Step 4: wrap in SDPB format *)
    Table[PositiveMatrixWithPrefactor[1, tempB[[i]]], {i, 1, tempB // Length}]
];
