# flybrainaligner

This repo collects the related software and pipelines developed for aligning fly brains.

## Install

Create a folder "Toolkits".

```
mkdir Toolkits
cd Toolkits
mkdir ANTS
mkdir FSL
mkdir Vaa3D
```

### Install [Vaa3D][] on Linux with [Qt][]4.

With cmake (recommended):
```
cd vaa3d
./build.cmake -h5j install
```

With shell script:
```
cd vaa3d
./build.linux -B -m -j8
```

Copy "vaa3d" and the "plugins" folder to "Toolkits/Vaa3D"

### Install [ANTs][]

```
mkdir build
cd build
ccmake ..
make -j8
```

Copy "ANTS" and "WarpImageMultiTransform" to "Toolkits/ANTS".

### Install [FSL][]

Download the fsl from the official website and copy "fsl/bin/flirt" to "Toolkits/FSL".

## Usage

See [brainaligner][].

## Reference
1. Peng, H., Ruan, Z., Long, F., Simpson, J.H., and Myers, E.W. (2010) "V3D enables real-time 3D visualization and quantitative analysis of large-scale biological image data sets," Nature Biotechnology, Vol. 28, No. 4, pp.348-353.
2. Murphy, S. D., Rokicki, K., Bruns, C., Yu, Y., Foster, L., Trautman, E., ... & Clack, N. (2014). The janelia workstation for neuroscience. Keystone Big Data in Biology. san francisco. CA.

## Author information
Please contact Yang Yu (yuy.cse@gmail.com) if you have any questions.

##

[Vaa3D]: http://vaa3d.org
[Qt]: https://www.qt.io
[HDF5]: https://support.hdfgroup.org/HDF5
[ANTs]: https://github.com/stnava/ANTs.git
[FSL]: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki
[brainaligner]: https://github.com/gnayuy/flybrainaligner/tree/master/pipelines/brainaligner
