"""Run a single RGB image through a trained DORN checkpoint and dump the
predicted local-frame layers (surface normal, 3D tangent directions, and the
2D projected tangent field) as PNGs.

Usage:
    python infer.py --image path/to/image.jpg --checkpoint checkpoints/dorn.cpkt --out out/

Optional camera intrinsics (fx, fy, cx, cy) default to the ScanNet values the
model was trained with; pass your own if known for better accuracy.
"""
import argparse
import os

import numpy as np
import skimage.io as sio
import torch

import misc_compat as misc
from dorn import DORN

INPUT_SIZE = (240, 320)  # (height, width), matches training resolution


def build_input(image_path, intrinsics):
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
    # map unit vector components from [-1, 1] to [0, 255]
    img = np.transpose(vec, (1, 2, 0))
    return ((img * 0.5 + 0.5) * 255).clip(0, 255).astype('uint8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, help='Path to an input RGB image')
    parser.add_argument('--checkpoint', default='checkpoints/dorn.cpkt')
    parser.add_argument('--out', default='out')
    parser.add_argument('--intrinsics', type=float, nargs=4, default=[577.591, 318.905, 578.73, 242.684],
                         metavar=('FX', 'CX', 'FY', 'CY'))
    parser.add_argument('--device', default='cuda' if torch.cuda.is_available() else 'cpu', choices=['cpu', 'cuda'])
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)

    device = torch.device(args.device)

    cnn = DORN(channel=5, output_channel=13, pretrained=False)
    cnn.load_state_dict(torch.load(args.checkpoint, map_location=device))
    cnn = cnn.to(device).eval()

    input_tensor, color_img = build_input(args.image, args.intrinsics)
    input_tensor = input_tensor.to(device)

    with torch.no_grad():
        outputs = cnn(input_tensor)[0].cpu().numpy()

    projection = outputs[0:4]      # 2D projected tangent field (Qx, Qy)
    tangent_x = normalize(outputs[4:7])   # 3D principal direction #1
    tangent_y = normalize(outputs[7:10])  # 3D principal direction #2
    normal = normalize(outputs[10:13])    # surface normal

    sio.imsave(os.path.join(args.out, 'input.png'), color_img)
    sio.imsave(os.path.join(args.out, 'normal.png'), vector_to_rgb(normal))
    sio.imsave(os.path.join(args.out, 'tangent_x.png'), vector_to_rgb(tangent_x))
    sio.imsave(os.path.join(args.out, 'tangent_y.png'), vector_to_rgb(tangent_y))

    Qx = np.ascontiguousarray(np.transpose(projection[0:2], (1, 2, 0)).astype('float32'))
    Qy = np.ascontiguousarray(np.transpose(projection[2:4], (1, 2, 0)).astype('float32'))
    color_float = np.ascontiguousarray(color_img.astype('float32') / 255.0)

    import Render.render as render
    render.visualizeDirection(os.path.join(args.out, 'tangent_field.png'), color_float, Qx, Qy)

    print('Wrote input.png, normal.png, tangent_x.png, tangent_y.png, tangent_field.png to', args.out)


if __name__ == '__main__':
    main()
