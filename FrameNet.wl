(* ::Package:: *)

BeginPackage["FrameNet`"];

StartFrameNetSession::usage = "StartFrameNetSession[] starts an ExternalSession for Python with framenet_bridge loaded.";

StopFrameNetSession::usage = "StopFrameNetSession[] or StopFrameNetSession[session] terminates the background or specified Python session.";

FrameNetInfo::usage = "FrameNetInfo[] or FrameNetInfo[session] returns metadata about PyTorch, device, and available layers.";

FrameNetPredict::usage = "FrameNetPredict[image, opts] runs the DORN checkpoint on image and returns an Association with the input image plus the predicted Normal, TangentX, TangentY (unit-vector arrays) and Projection (2D projected tangent field) layers, as both raw arrays and displayable Images.";

FrameNetTangentField::usage = "FrameNetTangentField[image, opts] renders the projected tangent-field streamline overlay for image and returns it as an Image.";

FrameNetDoctor::usage = "FrameNetDoctor[] runs diagnostic checks on the Python environment, PyTorch, bridge script, checkpoint, and device availability.";

$DefaultFrameNetSession::usage = "$DefaultFrameNetSession holds the automatically managed background Python session.";

$FrameNetPython::usage = "$FrameNetPython optionally specifies the explicit path to the Python executable.";

Begin["`Private`"];

Options[FrameNetPredict] = {"Checkpoint" -> Automatic, "Intrinsics" -> Automatic, "Device" -> Automatic};
Options[FrameNetTangentField] = Options[FrameNetPredict];

$DefaultFrameNetSession = None;
If[!ValueQ[$FrameNetPython], $FrameNetPython = None];

getPackageRoot[] :=
    Module[{dir},
        dir = Quiet[PacletObject["FrameNet"]["Location"]];
        If[StringQ[dir] && DirectoryQ[dir], Return[dir, Module]];
        dir = DirectoryName[$InputFileName];
        If[StringQ[dir] && dir =!= "" && DirectoryQ[dir], Return[dir, Module]];
        Directory[]
    ];

findVenvPython[] :=
    Module[{root, envVal, candidates, found},
        (* 1. Explicit variable override *)
        If[StringQ[$FrameNetPython] && FileExistsQ[$FrameNetPython],
            Return[$FrameNetPython, Module]
        ];
        (* 2. Environment variable override *)
        envVal = Environment["FRAMENET_PYTHON"];
        If[StringQ[envVal] && envVal =!= "" && FileExistsQ[envVal],
            Return[envVal, Module]
        ];
        (* 3. Candidate venv locations *)
        root = getPackageRoot[];
        candidates = {
            FileNameJoin[{root, ".venv", "bin", "python"}],
            FileNameJoin[{root, ".venv", "bin", "python3"}],
            FileNameJoin[{root, ".venv", "Scripts", "python.exe"}],
            FileNameJoin[{Directory[], ".venv", "bin", "python"}],
            FileNameJoin[{Directory[], ".venv", "bin", "python3"}],
            FileNameJoin[{Directory[], ".venv", "Scripts", "python.exe"}],
            FileNameJoin[{ParentDirectory[root], ".venv", "bin", "python"}],
            FileNameJoin[{ParentDirectory[root], ".venv", "Scripts", "python.exe"}]
        };
        found = SelectFirst[candidates, FileExistsQ, None];
        If[found =!= None, Return[found, Module]];

        (* 4. Wolfram ExternalEvaluators discovery fallback *)
        Quiet[
            With[{evals = FindExternalEvaluators["Python"]},
                If[ListQ[evals] && Length[evals] > 0,
                    Return[Lookup[First[evals], "Executable", "python3"], Module]
                ]
            ]
        ];

        (* 5. Standard fallback *)
        If[$OperatingSystem === "Windows", "python.exe", "python3"]
    ];

findBridgeScript[] :=
    Module[{root, bridgeAsset, candidates, found},
        bridgeAsset = Quiet[PacletObject["FrameNet"]["AssetLocation", "Bridge"]];
        If[StringQ[bridgeAsset] && FileExistsQ[bridgeAsset],
            Return[bridgeAsset, Module]
        ];
        root = getPackageRoot[];
        candidates = {
            FileNameJoin[{root, "framenet_bridge.py"}],
            FileNameJoin[{Directory[], "framenet_bridge.py"}],
            FileNameJoin[{ParentDirectory[root], "framenet_bridge.py"}]
        };
        found = SelectFirst[candidates, FileExistsQ, None];
        If[found =!= None,
            found,
            FileNameJoin[{root, "framenet_bridge.py"}]
        ]
    ];

findDefaultCheckpoint[] :=
    Module[{root},
        root = getPackageRoot[];
        FileNameJoin[{root, "src", "checkpoints", "dorn.cpkt"}]
    ];

resolveCheckpoint[Automatic] := findDefaultCheckpoint[];
resolveCheckpoint[path_String] := path;

resolveIntrinsics[Automatic] := None;
resolveIntrinsics[list_List] := list;

resolveDevice[dev_] := If[dev === Automatic || dev === None, None, ToString[dev]];

StartFrameNetSession::nobridge = "Cannot find framenet_bridge.py at `1`. Ensure the paclet/repository is intact.";
StartFrameNetSession::nopython = "Failed to launch Python session with executable `1`. Check if .venv is installed.";

StartFrameNetSession[opts___] :=
    Module[{pythonPath, session, bridgePath, srcDir},
        pythonPath = findVenvPython[];
        session = Quiet[Check[
            StartExternalSession[<|"System" -> "Python", "Executable" -> pythonPath|>],
            $Failed
        ]];
        If[session === $Failed || !MatchQ[session, _ExternalSessionObject],
            Message[StartFrameNetSession::nopython, pythonPath];
            Return[$Failed, Module]
        ];
        bridgePath = findBridgeScript[];
        If[FileExistsQ[bridgePath],
            srcDir = FileNameJoin[{DirectoryName[bridgePath], "src"}];
            Quiet[ExternalEvaluate[session, "import sys; sys.path.insert(0, " <> ToString[
                InputForm[srcDir]] <> ") if " <> ToString[InputForm[srcDir]] <> " not in sys.path else None"
            ]];
            ExternalEvaluate[session, File[bridgePath]]
            ,
            Message[StartFrameNetSession::nobridge, bridgePath]
        ];
        session
    ];

$kernelExitRegistered = False;

registerKernelExitCleanup[] :=
    If[!$kernelExitRegistered,
        $kernelExitRegistered = True;
        If[NameQ["System`AddHandler"],
            Quiet[AddHandler["KernelExit", Function[StopFrameNetSession[]]]]
        ];
    ];

sessionValidQ[session_ExternalSessionObject] :=
    TrueQ[Quiet[Check[StringQ[ExternalEvaluate[session, "'ok'"]], False]]];

sessionValidQ[___] := False;

ensureSession[session_ExternalSessionObject] := session;

ensureSession[___] :=
    Module[{},
        If[!sessionValidQ[$DefaultFrameNetSession],
            StopFrameNetSession[];
            $DefaultFrameNetSession = StartFrameNetSession[];
            registerKernelExitCleanup[];
        ];
        $DefaultFrameNetSession
    ];

StopFrameNetSession[] :=
    Module[{},
        If[MatchQ[$DefaultFrameNetSession, _ExternalSessionObject],
            Quiet[DeleteObject[$DefaultFrameNetSession]];
            $DefaultFrameNetSession = None;
        ];
    ];

StopFrameNetSession[session_ExternalSessionObject] :=
    (
        If[session === $DefaultFrameNetSession,
            $DefaultFrameNetSession = None
        ];
        Quiet[DeleteObject[session]]
    );

FrameNetInfo[session_ExternalSessionObject] :=
    ExternalEvaluate[session, <|"Command" -> "framenet_info", "Arguments" -> {}|>];

FrameNetInfo[] := FrameNetInfo[ensureSession[]];

withTemporaryImageFile[image_Image, body_] :=
    Module[{dir, file, result},
        dir = CreateDirectory[FileNameJoin[{$TemporaryDirectory, CreateUUID["framenet-"]}]];
        file = FileNameJoin[{dir, "image.png"}];
        Export[file, ColorConvert[image, "RGB"], "PNG"];
        result = Check[body[file, dir], $Failed];
        Quiet[DeleteDirectory[dir, DeleteContents -> True]];
        result
    ];

vectorImage[arr_] := Image[(Normal[arr] + 1.0)/2.0, ColorSpace -> "RGB"];

(* Predict - Explicit Session *)

FrameNetPredict[session_ExternalSessionObject, image_Image, opts : OptionsPattern[]] :=
    withTemporaryImageFile[image,
        Function[{file, dir},
            Module[{raw, assoc},
                raw = ExternalEvaluate[session, <|"Command" -> "framenet_predict", "Arguments" -> {
                    file,
                    resolveCheckpoint[OptionValue["Checkpoint"]],
                    resolveIntrinsics[OptionValue["Intrinsics"]],
                    resolveDevice[OptionValue["Device"]]
                }|>];
                If[!AssociationQ[raw], Return[raw, Module]];
                assoc = <|
                    "Input" -> Image[raw["input"]],
                    "Normal" -> raw["normal"],
                    "NormalImage" -> vectorImage[raw["normal"]],
                    "TangentX" -> raw["tangent_x"],
                    "TangentXImage" -> vectorImage[raw["tangent_x"]],
                    "TangentY" -> raw["tangent_y"],
                    "TangentYImage" -> vectorImage[raw["tangent_y"]],
                    "Projection" -> raw["projection"]
                |>;
                assoc
            ]
        ]
    ];

FrameNetPredict[image_Image, opts : OptionsPattern[]] :=
    FrameNetPredict[ensureSession[], image, opts];

(* Tangent Field Visualization - Explicit Session *)

FrameNetTangentField[session_ExternalSessionObject, image_Image, opts : OptionsPattern[]] :=
    withTemporaryImageFile[image,
        Function[{file, dir},
            Module[{outFile, result},
                outFile = FileNameJoin[{dir, "tangent_field.png"}];
                result = ExternalEvaluate[session, <|"Command" -> "framenet_render_tangent_field", "Arguments" -> {
                    file,
                    resolveCheckpoint[OptionValue["Checkpoint"]],
                    outFile,
                    resolveIntrinsics[OptionValue["Intrinsics"]],
                    resolveDevice[OptionValue["Device"]]
                }|>];
                If[StringQ[result] && FileExistsQ[result], Import[result], $Failed]
            ]
        ]
    ];

FrameNetTangentField[image_Image, opts : OptionsPattern[]] :=
    FrameNetTangentField[ensureSession[], image, opts];

(* Diagnostic Doctor *)

FrameNetDoctor[] :=
    Module[{pythonPath, bridgePath, checkpointPath, pyExists, bridgeExists, checkpointExists, session, info, res},
        pythonPath = findVenvPython[];
        bridgePath = findBridgeScript[];
        checkpointPath = findDefaultCheckpoint[];
        pyExists = If[StringQ[pythonPath] && !MemberQ[{"python", "python3", "python.exe"}, pythonPath], FileExistsQ[pythonPath], True];
        bridgeExists = StringQ[bridgePath] && FileExistsQ[bridgePath];
        checkpointExists = StringQ[checkpointPath] && FileExistsQ[checkpointPath];

        res = <|
            "PackageRoot" -> getPackageRoot[],
            "PythonExecutable" -> pythonPath,
            "PythonExists" -> pyExists,
            "BridgeScript" -> bridgePath,
            "BridgeExists" -> bridgeExists,
            "DefaultCheckpoint" -> checkpointPath,
            "CheckpointExists" -> checkpointExists,
            "SessionStatus" -> "Not Started",
            "PyTorchVersion" -> "Unknown",
            "Device" -> "Unknown",
            "CUDAAvailable" -> False,
            "Status" -> "Pending",
            "Notes" -> {}
        |>;

        If[!bridgeExists,
            res["Status"] = "Error";
            res["Notes"] = Append[res["Notes"], "Bridge script framenet_bridge.py not found at " <> ToString[bridgePath]];
            Return[res, Module];
        ];

        If[!checkpointExists,
            res["Notes"] = Append[res["Notes"], "Checkpoint not found at " <> ToString[checkpointPath] <> ". Run src/checkpoints/download.sh."];
        ];

        session = Quiet[Check[
            StartExternalSession[<|"System" -> "Python", "Executable" -> pythonPath|>],
            $Failed
        ]];

        If[session === $Failed || !MatchQ[session, _ExternalSessionObject],
            res["Status"] = "Error";
            res["SessionStatus"] = "Launch Failed";
            res["Notes"] = Append[res["Notes"], "Failed to launch Python. Ensure .venv is installed (uv sync)."];
            Return[res, Module];
        ];

        res["SessionStatus"] = "Connected";

        Quiet[ExternalEvaluate[session, "import sys; sys.path.insert(0, " <> ToString[
            InputForm[FileNameJoin[{DirectoryName[bridgePath], "src"}]]] <> ") if " <> ToString[
            InputForm[FileNameJoin[{DirectoryName[bridgePath], "src"}]]] <> " not in sys.path else None"
        ]];
        Quiet[ExternalEvaluate[session, File[bridgePath]]];
        info = Quiet[Check[ExternalEvaluate[session, <|"Command" -> "framenet_info", "Arguments" -> {}|>], $Failed]];
        Quiet[DeleteObject[session]];

        If[AssociationQ[info],
            res["PyTorchVersion"] = Lookup[info, "pytorch_version", "Unknown"];
            res["Device"] = Lookup[info, "device", "Unknown"];
            res["CUDAAvailable"] = Lookup[info, "cuda_available", False];
            res["Status"] = "OK";
            res["Notes"] = Append[res["Notes"], "Environment verified successfully. Device: " <> ToString[res["Device"]]];
            ,
            res["Status"] = "Warning";
            res["Notes"] = Append[res["Notes"], "Python connected, but framenet_bridge failed to load dependencies. Run `uv sync`."];
        ];

        res
    ];

End[];

EndPackage[];
