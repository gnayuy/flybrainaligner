#!/bin/bash
#
# 40x fly brain alignment pipeline 2.0, Janurary 14, 2013
#

DIR=$(cd "$(dirname "$0")"; pwd)

####
# func
####
is_file_exist()
{
local f="$1"
[[ -f "$f" ]] && return 0 || return 1
}

####
# TOOLKITS
####

Vaa3D="$DIR/../Toolkits/Vaa3D/vaa3d"
BRAINALIGNER="$DIR/../Toolkits/JBA/brainaligner"
ANTS="$DIR/../Toolkits/ANTS/ANTS"
MAGICK="$DIR/../../../ImageMagick-6.7.3-2"
TIFF="/groups/jacs/jacsHosts/servers/jacs/executables/tiff"

export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$MAGICK/lib:$TIFF/lib"

##################
# inputs
##################

NUMPARAMS=$#
if [ $NUMPARAMS -lt 3 ]
then
echo " "
echo " USAGE ::  "
echo " sh brainalign.sh <template_dir> <input_file> <output_dir> <optical_res>"
echo " "
exit
fi

TEMPLATE_DIR=$1
INPUT_FILE=$2
FINAL_OUTPUT=$3
OPTICAL_RESOLUTION=$4
FINAL_DIR=${FINAL_OUTPUT%/*}
FINAL_STUB=${FINAL_OUTPUT%.*}
OUTPUT_FILENAME=`basename $FINAL_OUTPUT`

WORKING_DIR=$FINAL_DIR/temp
mkdir $WORKING_DIR
cd $WORKING_DIR

echo "Run Dir: $DIR"
echo "Working Dir: $WORKING_DIR"
echo "Input file: $INPUT_FILE"
echo "Final Output Dir: $FINAL_DIR"

EXT=${INPUT_FILE#*.}
if [ $EXT == "v3dpbd" ]; then
    echo "~ Converting v3dpbd to v3draw"
    PBD_INPUT_FILE=$INPUT_FILE
    INPUT_FILE_STUB=`basename $PBD_INPUT_FILE`
    INPUT_FILE="$WORKING_DIR/${INPUT_FILE_STUB%.*}.v3draw"
    $Vaa3D -cmd image-loader -convert "$PBD_INPUT_FILE" "$INPUT_FILE"
fi

# template
CMPBND="$TEMPLATE_DIR/wfb_atx_template_rec2_boundaries.tif"
TMPMIPNULL="$TEMPLATE_DIR/templateMIPnull.tif"
ATLAS="$TEMPLATE_DIR/wfb_atx_template_ori.tif"

# output
OUTPUT="$WORKING_DIR/wb40x_"
SUBPREFIX=$OUTPUT

# subject
SUBJECT=$INPUT_FILE
SUBJECT_REFNO=3

# target
TARGET="$TEMPLATE_DIR/wfb_atx_template_rec2.tif"
TARGET_REFNO=1
TARGET_MARKER="$TEMPLATE_DIR/wfb_atx_template_rec2.marker"

# mips
MIP1=$SUBPREFIX"mip1.tif"
MIP2=$SUBPREFIX"mip2.tif"
MIP3=$SUBPREFIX"mip3.tif"

# png mips
PNG_MIP1=$SUBPREFIX"mip1.png"
PNG_MIP2=$SUBPREFIX"mip2.png"
PNG_MIP3=$SUBPREFIX"mip3.png"

####################################
# sampling from 0.3um 0.38um to 0.62um
####################################

SUBSS=$SUBPREFIX"Subsampled.v3draw"
echo "~ Running isampler on $SUBJECT"
$Vaa3D -x ireg -f isampler -i $SUBJECT -o $SUBSS -p "#x 0.5901 #y 0.5901 #z 0.7474"

####################################
# flip along z
####################################

SUBSSFLIP=$SUBPREFIX"ssFliped.v3draw"
echo "~ Running zflip on $SUBSS"
$Vaa3D -x ireg -f zflip -i $SUBSS -o $SUBSSFLIP

####################################
# resizing
####################################

SUBPP=$SUBPREFIX"Preprocessed.v3draw"
echo "~ Running prepare20xData on $SUBSSFLIP"
$Vaa3D -x ireg -f prepare20xData -o $SUBPP -p "#s $SUBSSFLIP #t $TARGET"

####################################
# brain alignment
####################################

##################
# global alignment
##################

GAOUTPUT=$SUBPREFIX"Global.v3draw"
TARGET_REFNO=`expr $TARGET_REFNO - 1`;
SUBJECT_REFNO=`expr $SUBJECT_REFNO - 1`;

MAXITERATIONS=10000x10000x10000
SAMPLERATIO=0.5

TEMPTARGET=${OUTPUT}"temptargettx.tif"
if ( is_file_exist "$TEMPTARGET" )
then
echo "Temp TARGET exists"
else
echo "~ Creating a symbolic link to 20x target "
ln -s ${TARGET} ${TEMPTARGET}
fi
TARGET=${TEMPTARGET}

STRT=`echo $TARGET | awk -F\. '{print $1}'`
STRS=`echo $SUBPP | awk -F\. '{print $1}'`

FIXED=$STRT"_c"$TARGET_REFNO".nii"
MOVING=$STRS"_c"$SUBJECT_REFNO".nii"

MOVINGC1=$STRS"_c0.nii"
MOVINGC2=$STRS"_c1.nii"
MOVINGC3=$STRS"_c2.nii"

echo "~ Converting to Nifti images"
$Vaa3D -x ireg -f NiftiImageConverter -i $TARGET
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBPP

STRT=`echo $FIXED | awk -F\. '{print $1}'`
FIXEDDS=$STRT"_ds.nii"
STRS=`echo $MOVING | awk -F\. '{print $1}'`
MOVINGDS=$STRS"_ds.nii"

echo "~ Downsampling"
$Vaa3D -x ireg -f resamplebyspacing -i $FIXED -o $FIXEDDS -p "#x 0.5 #y 0.5 #z 0.5"
$Vaa3D -x ireg -f resamplebyspacing -i $MOVING -o $MOVINGDS -p "#x 0.5 #y 0.5 #z 0.5"

SIMMETRIC=$SUBPREFIX"cc"
AFFINEMATRIX=$SUBPREFIX"ccAffine.txt"

echo "~ Running global alignment"
$ANTS 3 -m MI[ $FIXEDDS, $MOVINGDS, 1, 32] -o $SIMMETRIC -i 0 --number-of-affine-iterations $MAXITERATIONS --rigid-affine false

echo "~ Warping"
$Vaa3D -x ireg -f iwarp -o $GAOUTPUT -p "#s $SUBPP #t $TARGET #a $AFFINEMATRIX"

##################
# local alignment
##################

# GAOUTPUT_C3 is the reference
GAOUTPUT_C0=$SUBPREFIX"Global_c0.v3draw"
GAOUTPUT_C1=$SUBPREFIX"Global_c1.v3draw"
GAOUTPUT_C2=$SUBPREFIX"Global_c2.v3draw"
echo "~ Running splitColorChannels on $GAOUTPUT"
$Vaa3D -x ireg -f splitColorChannels -i $GAOUTPUT

LAOUTPUT_C0=$SUBPREFIX"Local_c0.v3draw"
LAOUTPUT_C1=$SUBPREFIX"Local_c1.v3draw"
LAOUTPUT_C2=$SUBPREFIX"Local_c2.v3draw"
CSVT=$LAOUTPUT_C2"_target.csv"
CSVS=$LAOUTPUT_C2"_subject.csv"

echo "~ Running local alignment on $GAOUTPUT_C2"
$BRAINALIGNER -t $TARGET -s $GAOUTPUT_C2 -w 10 -o $LAOUTPUT_C2 -L $TARGET_MARKER -B 1280 -H 2

echo "~ Running local alignment on $GAOUTPUT_C0"
$BRAINALIGNER -t $TARGET -s $GAOUTPUT_C0 -w 10 -o $LAOUTPUT_C0 -L $CSVT -l $CSVS -B 1280 -H 2

echo "~ Running local alignment on $GAOUTPUT_C1"
$BRAINALIGNER -t $TARGET -s $GAOUTPUT_C1 -w 10 -o $LAOUTPUT_C1 -L $CSVT -l $CSVS -B 1280 -H 2

LA_OUTPUT=$SUBPREFIX"Warped.v3draw"
echo "~ Running mergeColorChannels"
$Vaa3D -x ireg -f mergeColorChannels -i $LAOUTPUT_C1 $LAOUTPUT_C0 $LAOUTPUT_C2 $CMPBND -o $LA_OUTPUT

####################################
# resize output
####################################

PREPARED_OUTPUT=$SUBPREFIX"Aligned.v3draw"
echo "~ Running prepare20xData to generate final output"
$Vaa3D -x ireg -f prepare20xData -o $PREPARED_OUTPUT -p "#s $LA_OUTPUT #t $ATLAS"

####################################
# MIPS
####################################

# GAOUTPUT_C3 is the reference
AOUTPUT_C0=$SUBPREFIX"Aligned_c0.v3draw"
AOUTPUT_C1=$SUBPREFIX"Aligned_c1.v3draw"
AOUTPUT_C2=$SUBPREFIX"Aligned_c2.v3draw"
AOUTPUT_C3=$SUBPREFIX"Aligned_c3.v3draw"

echo "~ Running splitColorChannels on $PREPARED_OUTPUT"
$Vaa3D -x ireg -f splitColorChannels -i $PREPARED_OUTPUT
TMPOUTPUT=$SUBPREFIX"tmp.v3draw"

echo "~ Running mergeColorChannels to generate $TMPOUTPUT"
$Vaa3D -x ireg -f mergeColorChannels -i $AOUTPUT_C0 $AOUTPUT_C1 $AOUTPUT_C2 -o $TMPOUTPUT
echo "~ Running ireg's zmip on $TMPOUTPUT"
$Vaa3D -x ireg -f zmip -i $TMPOUTPUT -o $MIP3

STR=`echo $MIP3 | awk -F\. '{print $1}'`
TOUTPUT_C0=$STR"_c0.v3draw"
TOUTPUT_C1=$STR"_c1.v3draw"
TOUTPUT_C2=$STR"_c2.v3draw"

echo "~ Running splitColorChannels on $MIP3"
$Vaa3D -x ireg -f splitColorChannels -i $MIP3
echo "~ Running mergeColorChannels to generate $MIP2"
$Vaa3D -x ireg -f mergeColorChannels -i $TOUTPUT_C0 $TMPMIPNULL $TOUTPUT_C2 -o $MIP2
echo "~ Running mergeColorChannels to generate $MIP1"
$Vaa3D -x ireg -f mergeColorChannels -i $TMPMIPNULL $TOUTPUT_C1 $TOUTPUT_C2 -o $MIP1

echo "~ Running iContrastEnhancer"
$Vaa3D -x ireg -f iContrastEnhancer -i $MIP1 -o $MIP1 -p "#m 5"
$Vaa3D -x ireg -f iContrastEnhancer -i $MIP2 -o $MIP2 -p "#m 5"
$Vaa3D -x ireg -f iContrastEnhancer -i $MIP3 -o $MIP3 -p "#m 5"

$MAGICK/bin/convert -flip $MIP1 $PNG_MIP1
$MAGICK/bin/convert -flip $MIP2 $PNG_MIP2
$MAGICK/bin/convert -flip $MIP3 $PNG_MIP3

EXT=${FINAL_OUTPUT##*.}
if [ "$EXT" == "v3dpbd" ]
then
    ALIGNED_COMPRESSED="$WORKING_DIR/Aligned.v3dpbd"
    echo "~ Compressing output file to 8-bit PBD: $ALIGNED_COMPRESSED"
    $Vaa3D -cmd image-loader -convert8 $PREPARED_OUTPUT $ALIGNED_COMPRESSED
    PREPARED_OUTPUT=$ALIGNED_COMPRESSED
fi

echo "~ Computations complete"
echo "~ Space usage: " `du -h $WORKING_DIR`

echo "~ Moving final output to $FINAL_DIR"
mv $PREPARED_OUTPUT $FINAL_OUTPUT
mv $WORKING_DIR/*.png $FINAL_DIR

if [[ -f "$FINAL_OUTPUT" ]]; then
META=${FINAL_DIR}"/Aligned.properties"
echo "alignment.stack.filename=$OUTPUT_FILENAME" >> $META
echo "alignment.space.name=Unified 20x Alignment Space" >> $META
echo "alignment.resolution.voxels=0.62x0.62x0.62" >> $META
echo "alignment.image.size=1024x512x218" >> $META
echo "alignment.objective=20x" >> $META
fi

echo "~ Removing temp files"
rm -rf $WORKING_DIR

echo "~ Finished"

