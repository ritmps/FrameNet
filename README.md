# FrameNet: Learning Local Canonical Frames of 3D Surfaces from a Single RGB Image

## A lightly modified version that runs in Wolfram Mathematica

Source code for the paper:

Jingwei Huang, Yichao Zhou, Thomas Funkhouser, and Leonidas Guibas. [**FrameNet: Learning Local Canonical Frames of 3D Surfaces from a Single RGB Image**](http://stanford.edu/~jingweih/papers/framenet.pdf), ICCV 2019.

<!-- ## Processing Result -->
![FrameNet Teaser](https://github.com/hjwdzh/framenet/raw/master/img/teaser.jpg)

## Usage Pipeline

### Experiments
Please refer to [**src**](https://github.com/hjwdzh/framenet/raw/master/src/) directory for details.

### Fun AR Application
Please refer to [**src/demo**](https://github.com/hjwdzh/framenet/raw/master/src/demo/) directory for details.

### Rendering Toolbox
Please try the example from this [**repo**](https://github.com/hjwdzh/pyRender).

### Wolfram Mathematica Version

- Run the `install.sh` script to install the required packages and build the Python venv via `uv`.
- You can install the paclet by running the following commands in Wolfram Mathematica:
```wolfram
  PacletDirectoryLoad["/where/you/installed/FrameNet"];
  Needs["FrameNet`"];
  FrameNetDoctor[]
```
- There is a demo notebook `FrameNetDemo.nb` in the paclet directory. You can run it to see how to use the FrameNet paclet from Wolfram Mathematica.
- There is _very lightweight_ documentation available in the Mathematica help system. Look at the bottom of the Mathematica help window for `Add-Ons and Packages` and click on `FrameNet` to see the documentation.

## Author
- [Jingwei Huang](mailto:jingweih@stanford.edu)
- [Flip Phillips](mailto:flip.phillips@rit.edu)

&copy; 2019 Jingwei Huang, 2026 Flip Phillips. All Rights Reserved.

**IMPORTANT**: If you use this code please cite the following in any resulting publication:
```
@article{huang2019framenet,
  title={FrameNet: Learning Local Canonical Frames of 3D Surfaces from a Single RGB Image},
  author={Huang, Jingwei and Zhou, Yichao and Funkhouser, Thomas and Guibas, Leonidas},
  journal={arXiv preprint arXiv:1903.12305},
  year={2019}
}
```
