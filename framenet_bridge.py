"""Wolfram Language ExternalEvaluate bridge for the FrameNet paclet.

Loaded into a Python ExternalSession via FrameNet.wl. Exposes plain functions
that are invoked through <|"Command" -> "...", "Arguments" -> {...}|> requests;
each returns plain dicts/NumPy arrays that ExternalEvaluate converts to WL
associations/numeric arrays automatically.
"""
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore", category=UserWarning, module="torchvision")

try:
    _SRC_DIR = str(Path(__file__).resolve().parent / "src")
except NameError:
    _SRC_DIR = None  # __file__ is unavailable when exec'd via ExternalEvaluate[session, File[...]];
                      # the caller is expected to have already added the src/ dir to sys.path.
if _SRC_DIR and _SRC_DIR not in sys.path:
    sys.path.insert(0, _SRC_DIR)

import framenet_core  # noqa: E402


def framenet_info():
    """Return status and capability metadata for the bridge session."""
    return framenet_core.framenet_info()


def framenet_predict(image_path, checkpoint, intrinsics=None, device=None):
    """Run inference on an image file, returning input/normal/tangent_x/tangent_y/projection arrays (HxWxC)."""
    intr = tuple(intrinsics) if intrinsics else framenet_core.DEFAULT_INTRINSICS
    return framenet_core.predict(image_path, checkpoint, intr, device)


def framenet_render_tangent_field(image_path, checkpoint, out_path, intrinsics=None, device=None):
    """Run inference and write the projected tangent-field overlay PNG to out_path; returns out_path."""
    intr = tuple(intrinsics) if intrinsics else framenet_core.DEFAULT_INTRINSICS
    return framenet_core.render_tangent_field(image_path, checkpoint, out_path, intr, device)
