# flybrainaligner

This repo collects the related software and pipelines developed for aligning fly brains.

## Install

### Install Vaa3D in Linux with [Qt][]4.

With cmake (recommended):
```
cd vaa3d
./build.cmake -h5j install
```

with shell script:
```
cd vaa3d
./build.linux -B -m -j8
```

### Install [ANTs][]

```
mkdir build
cd build
ccmake ..
make -j8
```

After compiled ANTs, then copy ANTS and WarpImageMultiTransform to the "Toolkits" folder.

### Install [FSL][]

Download the binary executive fsl from the official website and copy FSL/bin/flirt to the "Toolkits" folder.

* I highly suggest creating a "Toolkits" folder and then "ANTS", "FSL", and "Vaa3D" folders within "Toolkits".

## Usage


## Reference
1. Peng, H., Ruan, Z., Long, F., Simpson, J.H., and Myers, E.W. (2010) "V3D enables real-time 3D visualization and quantitative analysis of large-scale biological image data sets," Nature Biotechnology, Vol. 28, No. 4, pp.348-353. (http://vaa3d.org) 
2. Murphy, S. D., Rokicki, K., Bruns, C., Yu, Y., Foster, L., Trautman, E., ... & Clack, N. (2014). The janelia workstation for neuroscience. Keystone Big Data in Biology. san francisco. CA.

##

[Qt]: https://www.qt.io
[HDF5]: https://support.hdfgroup.org/HDF5
[ANTs]: https://github.com/stnava/ANTs.git
[FSL]: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki
