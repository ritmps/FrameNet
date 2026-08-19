"""Reusable inference core for the FrameNet DORN checkpoint.

Shared by infer.py (CLI) and framenet_bridge.py (Wolfram Paclet ExternalEvaluate bridge).
"""
import numpy as np
import skimage.io as sio
import torch

import misc_compat as misc
from dorn import DORN

INPUT_SIZE = (240, 320)  # (height, width), matches training resolution
DEFAULT_INTRINSICS = (577.591, 318.905, 578.73, 242.684)  # fx, cx, fy, cy (ScanNet)

_model_cache = {}


def get_device(device=None):
    if device is None or (isinstance(device, str) and device.lower() in ('auto', 'automatic')):
        return torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    return torch.device(device)


def load_model(checkpoint, device=None):
    """Retrieve or build a cached DORN model loaded with the given checkpoint."""
    dev = get_device(device)
    key = (checkpoint, str(dev))
    if key not in _model_cache:
        cnn = DORN(channel=5, output_channel=13, pretrained=False)
        cnn.load_state_dict(torch.load(checkpoint, map_location=dev))
        cnn = cnn.to(dev).eval()
        _model_cache[key] = cnn
    return _model_cache[key]


def build_input(image_path, intrinsics=DEFAULT_INTRINSICS):
    fx, cx, fy, cy = intrinsics
    color_img = misc.imresize(sio.imread(image_path)[:, :, :3], INPUT_SIZE + (3,), 'nearest')
    color_tensor = np.transpose(color_img.astype('float32') / 255.0, (2, 0, 1))

    h, w = INPUT_SIZE
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    mesh_x = ((xx - cx) / fx).astype('float32')
    mesh_y = ((yy - cy) / fy).astype('float32')

    input_tensor = np.zeros((5, h, w), dtype='float32')
    input_tensor[0:3] = color_tensor
    input_tensor[3] = mesh_x
    input_tensor[4] = mesh_y
    return torch.from_numpy(input_tensor).unsqueeze(0), color_img


def normalize(vec):
    # vec: (3, H, W)
    length = np.sqrt((vec ** 2).sum(axis=0, keepdims=True)) + 1e-9
    return vec / length


def vector_to_rgb(vec):
    # map unit vector components from [-1, 1] to [0, 255], returned as HxWx3
    img = np.transpose(vec, (1, 2, 0))
    return ((img * 0.5 + 0.5) * 255).clip(0, 255).astype('uint8')


def predict(image_path, checkpoint, intrinsics=DEFAULT_INTRINSICS, device=None):
    """Run the checkpoint on an image, returning the input image plus the
    predicted local-frame layers as HxWxC float32 arrays (unit vectors in [-1, 1]
    for normal/tangent_x/tangent_y; raw cos/sin pairs for projection)."""
    dev = get_device(device)
    cnn = load_model(checkpoint, dev)

    input_tensor, color_img = build_input(image_path, intrinsics)
    input_tensor = input_tensor.to(dev)

    with torch.no_grad():
        outputs = cnn(input_tensor)[0].cpu().numpy()

    tangent_x = normalize(outputs[4:7])
    tangent_y = normalize(outputs[7:10])
    normal = normalize(outputs[10:13])

    return {
        'input': color_img.astype('float32') / 255.0,
        'normal': np.transpose(normal, (1, 2, 0)),
        'tangent_x': np.transpose(tangent_x, (1, 2, 0)),
        'tangent_y': np.transpose(tangent_y, (1, 2, 0)),
        'projection': np.transpose(outputs[0:4], (1, 2, 0)),
    }


def framenet_info():
    dev = get_device()
    return {
        'status': 'ok',
        'pytorch_version': torch.__version__,
        'device': str(dev),
        'cuda_available': torch.cuda.is_available(),
        'input_size': list(INPUT_SIZE),
        'default_intrinsics': list(DEFAULT_INTRINSICS),
        'layers': ['input', 'normal', 'tangent_x', 'tangent_y', 'projection'],
    }


def render_tangent_field(image_path, checkpoint, out_path, intrinsics=DEFAULT_INTRINSICS, device=None):
    """Run predict() and render the projected tangent field overlay to out_path (PNG)."""
    import Render.render as render

    result = predict(image_path, checkpoint, intrinsics, device)
    Qx = np.ascontiguousarray(result['projection'][:, :, 0:2].astype('float32'))
    Qy = np.ascontiguousarray(result['projection'][:, :, 2:4].astype('float32'))
    render.visualizeDirection(out_path, result['input'].astype('float32'), Qx, Qy)
    return out_path
