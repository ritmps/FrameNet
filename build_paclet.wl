(* ::Package:: *)
(* Script to package FrameNet into a standalone .paclet archive *)

dir = DirectoryName[$InputFileName];
If[dir === "" || !StringQ[dir], dir = Directory[]];

Print["Building Paclet from directory: ", dir];

If[!FileExistsQ[FileNameJoin[{dir, "PacletInfo.wl"}]],
  Print["Error: PacletInfo.wl not found in ", dir];
  Exit[1];
];

(* Create a clean staging directory *)
buildDir = FileNameJoin[{dir, "build", "FrameNet"}];
distDir = FileNameJoin[{dir, "dist"}];

Quiet[DeleteDirectory[FileNameJoin[{dir, "build"}], DeleteContents -> True]];
Quiet[CreateDirectory[distDir]];
CreateDirectory[buildDir];

(* Copy necessary paclet files *)
filesToCopy = {"PacletInfo.wl", "FrameNet.wl", "framenet_bridge.py", "README.md"};
Do[
  src = FileNameJoin[{dir, f}];
  If[FileExistsQ[src],
    CopyFile[src, FileNameJoin[{buildDir, f}]]
  ]
  ,
  {f, filesToCopy}
];

(* Copy Documentation directory *)
docSrc = FileNameJoin[{dir, "Documentation"}];
docDst = FileNameJoin[{buildDir, "Documentation"}];
If[DirectoryQ[docSrc],
  CopyDirectory[docSrc, docDst];
];

(* Copy the Python src package (model, checkpoints, Render lib) excluding
   downloaded/generated artifacts that the paclet consumer should fetch themselves *)
srcSrc = FileNameJoin[{dir, "src"}];
srcDst = FileNameJoin[{buildDir, "src"}];
If[DirectoryQ[srcSrc],
  CopyDirectory[srcSrc, srcDst];
  Quiet[DeleteDirectory[FileNameJoin[{srcDst, "__pycache__"}], DeleteContents -> True]];
  Quiet[DeleteDirectory[FileNameJoin[{srcDst, "data"}], DeleteContents -> True]];
  Quiet[DeleteFile[FileNameJoin[{srcDst, "checkpoints", "dorn.cpkt"}]]];
  Quiet[DeleteDirectory[FileNameJoin[{srcDst, "out"}], DeleteContents -> True]];
];

Print["Staged paclet files in: ", buildDir];

(* Create paclet archive *)
archive = Quiet[Check[CreatePacletArchive[buildDir, distDir], $Failed]];

If[StringQ[archive] && FileExistsQ[archive],
  Print["\n=== Paclet Archive Created Successfully ==="];
  Print["Archive file: ", archive];
  Print["\nTo install on another machine, run in Wolfram Language:"];
  Print["  PacletInstall[\"", archive, "\"]"];
  ,
  Print["Error: Could not create paclet archive."];
  Exit[1];
];

(* Clean up staging directory *)
Quiet[DeleteDirectory[FileNameJoin[{dir, "build"}], DeleteContents -> True]];
