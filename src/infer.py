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

from framenet_core import DEFAULT_INTRINSICS, predict, vector_to_rgb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, help='Path to an input RGB image')
    parser.add_argument('--checkpoint', default='checkpoints/dorn.cpkt')
    parser.add_argument('--out', default='out')
    parser.add_argument('--intrinsics', type=float, nargs=4, default=list(DEFAULT_INTRINSICS),
                         metavar=('FX', 'CX', 'FY', 'CY'))
    parser.add_argument('--device', default=None, choices=['cpu', 'cuda'])
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)

    result = predict(args.image, args.checkpoint, args.intrinsics, args.device)

    color_img = (result['input'] * 255).clip(0, 255).astype('uint8')
    sio.imsave(os.path.join(args.out, 'input.png'), color_img)
    sio.imsave(os.path.join(args.out, 'normal.png'), vector_to_rgb(np.transpose(result['normal'], (2, 0, 1))))
    sio.imsave(os.path.join(args.out, 'tangent_x.png'), vector_to_rgb(np.transpose(result['tangent_x'], (2, 0, 1))))
    sio.imsave(os.path.join(args.out, 'tangent_y.png'), vector_to_rgb(np.transpose(result['tangent_y'], (2, 0, 1))))

    Qx = np.ascontiguousarray(result['projection'][:, :, 0:2].astype('float32'))
    Qy = np.ascontiguousarray(result['projection'][:, :, 2:4].astype('float32'))

    import Render.render as render
    render.visualizeDirection(os.path.join(args.out, 'tangent_field.png'), result['input'].astype('float32'), Qx, Qy)

    print('Wrote input.png, normal.png, tangent_x.png, tangent_y.png, tangent_field.png to', args.out)


if __name__ == '__main__':
    main()
