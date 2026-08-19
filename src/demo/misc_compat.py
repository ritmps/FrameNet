"""Drop-in replacement for scipy.misc.imresize, removed in scipy>=1.3."""
import numpy as np
from skimage.transform import resize as _sk_resize

_INTERP_ORDERS = {'nearest': 0, 'bilinear': 1, 'lanczos': 1, 'bicubic': 3, 'cubic': 3}


def imresize(arr, size, interp='bilinear', mode=None):
    arr = np.asarray(arr)

    if isinstance(size, int):
        out_shape = tuple(int(round(d * size / 100.0)) for d in arr.shape[:2])
    elif isinstance(size, float):
        out_shape = tuple(int(round(d * size)) for d in arr.shape[:2])
    else:
        out_shape = tuple(size[:2])

    if arr.ndim == 3 and len(out_shape) == 2:
        out_shape = out_shape + (arr.shape[2],)

    order = _INTERP_ORDERS.get(interp, 1)
    is_float = mode == 'F' or np.issubdtype(arr.dtype, np.floating)

    out = _sk_resize(arr, out_shape, order=order, mode='edge',
                      anti_aliasing=(order != 0), preserve_range=True)

    if is_float:
        return out.astype(np.float32)
    return np.round(out).astype(arr.dtype)
