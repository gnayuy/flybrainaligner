#!/bin/sh

# developed by Yang Yu (yuy@janelia.hhmi.org) 03/23/2017
# genrate the alignment script
#

# Usages:
###
# Example 1 (for single brain): 
# $mkdir /nrs/scicompsoft/yuy/registration/images/VT005002_AE_01-20131024_33_I1
# $mkdir /nrs/scicompsoft/yuy/registration/images/VT005002_AE_01-20131024_33_I1/images
# $cp VT005002_AE_01-20131024_33_I1_*.nrrd /nrs/scicompsoft/yuy/registration/images/VT005002_AE_01-20131024_33_I1/images
# $sh genAlignScript.sh /nrs/scicompsoft/yuy/registration/images/VT005002_AE_01-20131024_33_I1 32
# $qsub -pe batch 32 -l broadwell=true -j y -b y -cwd -V /nrs/scicompsoft/yuy/registration/images/VT005002_AE_01-20131024_33_I1/alignCmd.sh
###
# Example 2 (for multiple brains):
# $for i in /nrs/scicompsoft/yuy/registration/images/*.nrrd; do j=${i%*_*}; mkdir $j; mkdir $j/images; done
# $for i in /nrs/scicompsoft/yuy/registration/images/*.nrrd; do j=${i%*_*}; mv $j* $j/images/; done
# $for i in /nrs/scicompsoft/yuy/registration/images/*; do sh genAlignScript.sh $i 32 $i/alignCmd.sh; done
# $for i in /nrs/scicompsoft/yuy/registration/images/*/alignCmd.sh; do qsub -pe batch 32 -l broadwell=true -j y -b y -cwd -V $i; done
# $qstat

#
INPUTDIR=$1
THREAD=$2
OUT=$3


echo "sh /nrs/scicompsoft/yuy/registration/brainAlignerJfrc2010Cmtk.sh $INPUTDIR $THREAD" >> $OUT
chmod 755 $OUT
