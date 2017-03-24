#!/bin/sh

# developed by Yang Yu (yuy@janelia.hhmi.org) 03/23/2017
# default input image folder will be used by cmtk "images"
# default temporary folder created by cmtk "Registration" and "reformatted"
# 

# env setting
CMTKDIR=/nrs/scicompsoft/yuy/Toolkits/CMTK/bin
CMTKALIGNER=${CMTKDIR}/munger
TEMPLATE='/nrs/scicompsoft/otsuna/Registration/JFRC2010_16bit.nrrd'

# input
INPUTDIR=$1
THREADS=$2

# alignment
cd $INPUTDIR
$CMTKALIGNER -b $CMTKDIR -a -w -r 0102030405 -X 26 -C 8 -G 80 -R 4 -A '--accuracy 0.8' -W '--accuracy 0.8' -T $THREADS -s $TEMPLATE images
