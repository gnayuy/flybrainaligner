#!/bin/bash
#
# fly brain alignment pipeline for polarity pair, version 1.0, 2013/1/1
#

################################################################################
#
# The pipeline is developed for aligning polarity fly brain.
# Target brain's resolution (0.46x0.46x1.0 and 0.19x0.19x0.38 um)
#
################################################################################


##################
# Basic Funcs
##################
DIR=$(cd "$(dirname "$0")"; pwd)
. $DIR/common.sh

##################
# Inputs
##################

parseParameters "$@"
CONFIGFILE=$CONFIG_FILE
TMPLDIR=$TEMPLATE_DIR
TOOLDIR=$TOOL_DIR
WORKDIR=$WORK_DIR
MP=$MOUNTING_PROTOCOL
NEUBRAIN=$INPUT1_NEURONS

# 63x parameters
SUBSX=$INPUT1_FILE
SUBSXREF=$INPUT1_REF
SUBSXNEURONS=$INPUT1_NEURONS
CHN=$INPUT1_CHANNELS

# 20x parameters
SUBTX=$INPUT2_FILE
SUBTXREF=$INPUT2_REF
SUBTXNEURONS=$INPUT2_NEURONS
RESX=$INPUT2_RESX
RESY=$INPUT2_RESY
RESZ=$INPUT2_RESZ

# tools
Vaa3D=`readItemFromConf $CONFIGFILE "Vaa3D"`
JBA=`readItemFromConf $CONFIGFILE "JBA"`
ANTS=`readItemFromConf $CONFIGFILE "ANTS"`
WARP=`readItemFromConf $CONFIGFILE "WARP"`
WARPMT=`readItemFromConf $CONFIGFILE "WARPMT"`

Vaa3D=${TOOLDIR}"/"${Vaa3D}
JBA=${TOOLDIR}"/"${JBA}
ANTS=${TOOLDIR}"/"${ANTS}
WARP=${TOOLDIR}"/"${WARP}
WARPMT=${TOOLDIR}"/"${WARPMT}

# templates
ATLAS=`readItemFromConf $CONFIGFILE "atlasFBTX"`
TARTX=`readItemFromConf $CONFIGFILE "tgtFBRCTX"`
TARREF=`readItemFromConf $CONFIGFILE "REFNO"`
RESSX_X=`readItemFromConf $CONFIGFILE "VSZX_63X_AS"`
RESSX_Y=`readItemFromConf $CONFIGFILE "VSZY_63X_AS"`
RESSX_Z=`readItemFromConf $CONFIGFILE "VSZZ_63X_AS"`

RESTX_X_IS=`readItemFromConf $CONFIGFILE "VSZX_20X_IS"`
RESTX_Y_IS=`readItemFromConf $CONFIGFILE "VSZY_20X_IS"`
RESTX_Z_IS=`readItemFromConf $CONFIGFILE "VSZZ_20X_IS"`

INITAFFINE=`readItemFromConf $CONFIGFILE "IDENTITYMATRIX"`

TARTX=${TMPLDIR}"/"${TARTX}
ATLAS=${TMPLDIR}"/"${ATLAS}
INITAFFINE=${TMPLDIR}"/"${INITAFFINE}

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "WORKDIR: $WORKDIR"
echo "SUBSX: $SUBSX"
echo "SUBSXREF: $SUBSXREF"
echo "SUBTX: $SUBTX"
echo "SUBTXREF: $SUBTXREF"
echo "RESX: $RESX"
echo "RESY: $RESY"
echo "RESZ: $RESZ"
echo "MP: $MP"
echo "NEUBRAIN: $NEUBRAIN"
message "Vars..."
echo "Vaa3D: $Vaa3D"
echo "JBA: $JBA"
echo "ANTS: $ANTS"
echo "WARP: $WARP"
echo "TARTX: $TARTX"
echo "TARREF: $TARREF"
echo "ATLAS: $ATLAS"
echo "INITAFFINE: $INITAFFINE"

echo ""

# convert inputs to raw format
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUBSX" SUBSX
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUBTX" SUBTX
echo "RAW SUB SX: $SUBSX"
echo "RAW SUB TX: $SUBTX"
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUBSXNEURONS" SUBSXNEURONS
echo "RAW SUBSXNEURONS: $SUBSXNEURONS"

OUTPUT=$WORKDIR"/Outputs"
FINALOUTPUT=$WORKDIR"/FinalOutputs"

if [ ! -d $OUTPUT ]; then 
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then 
mkdir $FINALOUTPUT
fi

SUBSXREF=$((SUBSXREF-1));

##################
# VOI Extraction
##################

# VECTASHIELD/DPX 
DPXSHRINKRATIO=1.0

if [[ $MP =~ "DPX Ethanol Mounting" ]]
then
    DPXSHRINKRATIO=0.82
elif [[ $MP =~ "DPX PBS Mounting" ]]
then
    DPXSHRINKRATIO=0.86
elif [[ $MP =~ "" ]]
then
    echo "Mounting protocol not specified, proceeding with DPXSHRINKRATIO=$DPXSHRINKRATIO"
else
    # other mounting protocol
    echo "Unknown mounting protocol: $MP"
fi

RESTX_X=`echo $DPXSHRINKRATIO*$RESTX_X_IS | bc -l`
RESTX_Y=`echo $DPXSHRINKRATIO*$RESTX_Y_IS | bc -l`
RESTX_Z=`echo $DPXSHRINKRATIO*$RESTX_Z_IS | bc -l`

#TARREF=$((TARREF-1));
#SUBREF=$((SUBREF-1));

### mountant refractive factor for DPX
DPXRI=1.55

MAXITERATIONS=10000x10000x10000x10000x10000
GRADDSCNTOPTS=0.5x0.95x1.e-4x1.e-4

SAMPLERATIO=2

### temporary target
TEMPTARGET=${OUTPUT}"/temptargettx.v3draw"
if ( is_file_exist "$TEMPTARGET" )
then
echo "TEMPTARGET: $TEMPTARGET exists"
else
#---exe---#
message " Creating a symbolic link to 20x target "
ln -s ${TARTX} ${TEMPTARGET}
fi

TARTX=$TEMPTARGET

### temporary subject
TEMPSUBJECT=${OUTPUT}"/tempsubjectsx.v3draw"
if ( is_file_exist "$TEMPSUBJECT" )
then
echo "TEMPSUBJECT: $TEMPSUBJECT exists"
else
#---exe---#
message " Creating a symbolic link to 63x subject "
ln -s ${SUBSX} ${TEMPSUBJECT}
fi

SUBSX=$TEMPSUBJECT


### extract the reference channels

SUBRAW=${OUTPUT}"/subtxraw.v3draw"

if ( is_file_exist "$SUBRAW" )
then
echo " SUBRAW: $SUBRAW exists"
else
#---exe---#
message " Converting the 20x subject to v3draw "
$Vaa3D -cmd image-loader -convert $SUBTX $SUBRAW;
fi


SUBTXRC=${OUTPUT}"/subtxREFCH.v3draw"

if ( is_file_exist "$SUBTXRC" )
then
echo " SUBTXRC: $SUBTXRC exists"
else
#---exe---#
message " Extracting the reference of the 20x subject "
$Vaa3D -x refExtract -f refExtract -i $SUBRAW -o $SUBTXRC -p "#c $SUBTXREF";
fi


### isotropic interpolation
SRX=`echo $RESX/$RESTX_X | bc -l`
SRY=`echo $RESY/$RESTX_Y | bc -l`
SRZ=`echo $RESZ/$RESTX_Z | bc -l`
SRZ=`echo $SRZ*$DPXRI | bc -l`

### isotropic
SUBTXIS=${OUTPUT}"/subtxIS.v3draw"

if ( is_file_exist "$SUBTXIS" )
then
echo " SUBTXIS: $SUBTXIS exists"
else
#---exe---#
message " Isotropic sampling 20x subject "
$Vaa3D -x ireg -f isampler -i $SUBTXRC -o $SUBTXIS -p "#x $SRX #y $SRY #z $SRZ"
fi


### sampling ratio from 20x to 63x 
SRT2SX=`echo $RESTX_X/$RESSX_X | bc -l`
SRT2SY=`echo $RESTX_Y/$RESSX_Y | bc -l`
SRT2SZ=`echo $RESTX_Z/$RESSX_Z | bc -l`

### sampling ratio from 63x to 20x
SRS2TX=`echo $RESSX_X/$RESTX_X | bc -l`
SRS2TY=`echo $RESSX_Y/$RESTX_Y | bc -l`
SRS2TZ=`echo $RESSX_Z/$RESTX_Z | bc -l`

### upsample 20x subject, 20x target to 63x scale

SUBTXUSRAW=${OUTPUT}"/subtxISUS.v3draw"
SUBTXUSREC=${OUTPUT}"/subtxISUSREC.v3draw"
TARTXUSRAW=${OUTPUT}"/temptargettxUS.v3draw"

SUBTXUSNII=${OUTPUT}"/subtxISUSREC_c0.nii"
TARTXUSNII=${OUTPUT}"/temptargettxUS_c0.nii"

if ( is_file_exist "$SUBTXUSRAW" )
then
echo " SUBTXUSRAW: $SUBTXUSRAW exists"
else
#---exe---#
message " Upsampling 20x subject to 63x scale "
$Vaa3D -x ireg -f isampler -i $SUBTXIS -o $SUBTXUSRAW -p "#x $SRT2SX #y $SRT2SY #z $SRT2SZ"
fi

if ( is_file_exist "$TARTXUSRAW" )
then
echo " TARTXUSRAW: $TARTXUSRAW exists"
else
#---exe---#
message " Upsampling 20x target to 63x scale "
$Vaa3D -x ireg -f isampler -i $TARTX -o $TARTXUSRAW -p "#x $SRT2SX #y $SRT2SY #z $SRT2SZ"
fi

if ( is_file_exist "$TARTXUSNII" )
then
echo " TARTXUSNII: $TARTXUSNII exists"
else
#---exe---#
message " Converting upsampled 20x subject into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $TARTXUSRAW
fi

if ( is_file_exist "$SUBTXUSREC" )
then
echo " SUBTXUSREC: $SUBTXUSREC exists"
else
#---exe---#
message " Resizing the upsampled 20x subject to upsampled 20x target "
$Vaa3D -x ireg -f prepare20xData -o $SUBTXUSREC -p "#s $SUBTXUSRAW #t $TARTXUSRAW"
fi

if ( is_file_exist "$SUBTXUSNII" )
then
echo " SUBTXUSNII: $SUBTXUSNII exists"
else
#---exe---#
message " Converting upsampled 20x subject into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBTXUSREC
fi

##################
# Alignment
##################

#
### global alignment
#

message " Global alignment "

MAXITERATIONS=10000x10000x10000x10000x10000
DSRATIO=0.5
USRATIO=2.0

### 1) global align $SUBTXIS to $TARTX

SIMMETRIC=${OUTPUT}"/txmi"
AFFINEMATRIX=${OUTPUT}"/txmiAffine.txt"

SUBTXUSNIIDS=${OUTPUT}"/subtxISUSREC_c0_ds.nii"
TARTXUSNIIDS=${OUTPUT}"/temptargettxUS_c0_ds.nii"

if ( is_file_exist "$SUBTXUSNIIDS" )
then
echo " SUBTXUSNIIDS: $SUBTXUSNIIDS exists"
else
#---exe---#
message " Downsampling upsampled 20x subject "
$Vaa3D -x ireg -f resamplebyspacing -i $SUBTXUSNII -o $SUBTXUSNIIDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

if ( is_file_exist "$TARTXUSNIIDS" )
then
echo " TARTXUSNIIDS: $TARTXUSNIIDS exists"
else
#---exe---#
message " Downsampling upsampled 20x target "
$Vaa3D -x ireg -f resamplebyspacing -i $TARTXUSNII -o $TARTXUSNIIDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

if ( is_file_exist "$AFFINEMATRIX" )
then
echo " AFFINEMATRIX: $AFFINEMATRIX exists"
else
#---exe---#
message " Global aligning upsampled 20x subject to upsampled 20x target "
$ANTS 3 -m  MI[ $TARTXUSNIIDS, $SUBTXUSNIIDS, 1, 32] -o $SIMMETRIC -i 0 --number-of-affine-iterations 10000x10000x10000 --rigid-affine true
fi


### 2) global align $SUBSX to $SUBTXUSRAW
message " Global aligning 63x subject to upsampled 20x subject "

# create a mask image for 63x subject

SUBSXMASK=${OUTPUT}"/subsxmask.v3draw"

SUBSXREC=${OUTPUT}"/subsxREC.v3draw"
SUBSXMASKREC=${OUTPUT}"/subsxmaskREC.v3draw"

if ( is_file_exist "$SUBSXMASK" )
then
echo " SUBSXMASK: $SUBSXMASK exists"
else
#---exe---#
message " Creating a mask image for the 63x subject "
$Vaa3D -x ireg -f createMaskImage -i $SUBSX -o $SUBSXMASK
fi

if ( is_file_exist "$SUBSXREC" )
then
echo " SUBSXREC: $SUBSXREC exists"
else
#---exe---#
message " Resizing the 63x subject and its mask image "
$Vaa3D -x ireg -f prepare20xData -o $SUBSXREC -p "#s $SUBSX #t $SUBTXUSREC"
fi

if(($CHN>0))
then
SUBSXRECC0=${OUTPUT}"/subsxREC_c0.v3draw"
fi

if(($CHN>1))
then
SUBSXRECC1=${OUTPUT}"/subsxREC_c1.v3draw"
fi

if(($CHN>2))
then
SUBSXRECC2=${OUTPUT}"/subsxREC_c2.v3draw"
fi

if(($CHN>3))
then
SUBSXRECC3=${OUTPUT}"/subsxREC_c3.v3draw"
fi

SUBSXRECRC=${OUTPUT}"/subsxREC_c"${SUBSXREF}".v3draw"

if ( is_file_exist "$SUBSXRECRC" )
then
echo " SUBSXRECRC: $SUBSXRECRC exists"
else
#---exe---#
message " Extracting the reference of the 63x subject "
$Vaa3D -x ireg -f splitColorChannels -i $SUBSXREC
fi

if ( is_file_exist "$SUBSXMASKREC" )
then
echo " SUBSXMASKREC: $SUBSXMASKREC exists"
else
#---exe---#
message " Resizing the 63x subject and its mask image "
$Vaa3D -x ireg -f prepare20xData -o $SUBSXMASKREC -p "#s $SUBSXMASK #t $SUBTXUSREC"
fi

# obtain translations by template matching 63x subject to upsampled 20x subject

STITCHFOLDER=${OUTPUT}"/stitch"

if [ ! -d $STITCHFOLDER ]; then 
mkdir $STITCHFOLDER
fi

TCFILE=$STITCHFOLDER"/stitched_image.tc"
TCTEXT=$STITCHFOLDER"/stitched_image.txt"
TCAFFINE=$STITCHFOLDER"/translations.txt"
SUBSXFORSTITCH=$STITCHFOLDER"/subsx.v3draw"
SUBTXFORSTITCH=$STITCHFOLDER"/subtx.v3draw"

SUBTXISUSDS=${OUTPUT}"/subtxISUSDS.v3draw"
SUBSXRCRFDS=${OUTPUT}"/subsxRCRFDS.v3draw"

if ( is_file_exist "$SUBTXISUSDS" )
then
echo " SUBTXISUSDS: $SUBTXISUSDS exists"
else
#---exe---#
message " Downsampling 20x subject "
$Vaa3D -x ireg -f isampler -i $SUBTXUSREC -o $SUBTXISUSDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO"
fi

if ( is_file_exist "$SUBSXRCRFDS" )
then
echo " SUBSXRCRFDS: $SUBSXRCRFDS exists"
else
#---exe---#
message " Downsampling 63x subject "
$Vaa3D -x ireg -f isampler -i $SUBSXRECRC -o $SUBSXRCRFDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO"
fi

if ( is_file_exist "$SUBTXFORSTITCH" )
then
echo " SUBTXFORSTITCH: $SUBTXFORSTITCH exists"
else
#---exe---#
message " Creating symbolic link for stitching "
ln -s $SUBTXISUSDS $SUBTXFORSTITCH
fi

if ( is_file_exist "$SUBSXFORSTITCH" )
then
echo " SUBSXFORSTITCH: $SUBSXFORSTITCH exists"
else
#---exe---#
message " Creating symbolic link for stitching "
ln -s $SUBSXRCRFDS $SUBSXFORSTITCH
fi

if ( is_file_exist "$TCFILE" )
then
echo " TCFILE: $TCFILE exists"
else
#---exe---#
message " Matching downsampled 63x subject to 20x subject "
$Vaa3D -x imageStitch -f v3dstitch -i $STITCHFOLDER -p "#c 1 #si 0";
fi

if ( is_file_exist "$TCTEXT" )
then
echo " TCTEXT: $TCTEXT exists"
else
#---exe---#
message " Creating symbolic link "
ln -s $TCFILE $TCTEXT
fi

if ( is_file_exist "$TCAFFINE" )
then
echo " TCAFFINE: $TCAFFINE exists"
else
#---exe---#
message " Convert tc file to insight transform "
$Vaa3D -x ireg -f convertTC2AM -i $TCTEXT -o $TCAFFINE -p "#x $USRATIO #y $USRATIO #z $USRATIO"
fi


### warp 63x subject and mask images

# translate

if(($CHN>0))
then
SUBSXRECC0TRANS=${OUTPUT}"/subsxREC_c0_translated.v3draw"
fi

if(($CHN>1))
then
SUBSXRECC1TRANS=${OUTPUT}"/subsxREC_c1_translated.v3draw"
fi

if(($CHN>2))
then
SUBSXRECC2TRANS=${OUTPUT}"/subsxREC_c2_translated.v3draw"
fi

if(($CHN>3))
then
SUBSXRECC3TRANS=${OUTPUT}"/subsxREC_c3_translated.v3draw"
fi

SUBSXRECRCTRANS=${OUTPUT}"/subsxREC_c"${SUBSXREF}"_translated.v3draw"

SUBSXMASKRECTRANS=${OUTPUT}"/subsxmaskREC_translated.v3draw"

if ( is_file_exist "$SUBSXRECRCTRANS" )
then
echo " SUBSXRECRCTRANS: $SUBSXRECRCTRANS exists"
else
#---exe---#
message " Translating recentered 63x subject and mask images "

if(($CHN>0))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC0TRANS -p "#s $SUBSXRECC0 #t $SUBTXUSREC #a $TCAFFINE"
fi

if(($CHN>1))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC1TRANS -p "#s $SUBSXRECC1 #t $SUBTXUSREC #a $TCAFFINE"
fi

if(($CHN>2))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC2TRANS -p "#s $SUBSXRECC2 #t $SUBTXUSREC #a $TCAFFINE"
fi

if(($CHN>3))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC3TRANS -p "#s $SUBSXRECC3 #t $SUBTXUSREC #a $TCAFFINE"
fi

$Vaa3D -x ireg -f iwarp -o $SUBSXMASKRECTRANS -p "#s $SUBSXMASKREC #t $SUBTXUSREC #a $TCAFFINE"
fi

# affine transform

if(($CHN>0))
then
SUBSXRECC0TRANS2=${OUTPUT}"/subsxREC_c0_translated_transformed.v3draw"
fi

if(($CHN>1))
then
SUBSXRECC1TRANS2=${OUTPUT}"/subsxREC_c1_translated_transformed.v3draw"
fi

if(($CHN>2))
then
SUBSXRECC2TRANS2=${OUTPUT}"/subsxREC_c2_translated_transformed.v3draw"
fi

if(($CHN>3))
then
SUBSXRECC3TRANS2=${OUTPUT}"/subsxREC_c3_translated_transformed.v3draw"
fi

SUBSXRECRCTRANS2=${OUTPUT}"/subsxREC_c"${SUBSXREF}"_translated_transformed.v3draw"

SUBSXMASKRECTRANS2=${OUTPUT}"/subsxmaskREC_translated_transformed.v3draw"

if ( is_file_exist "$SUBSXRECRCTRANS2" )
then
echo " SUBSXRECRCTRANS2: $SUBSXRECRCTRANS2 exists"
else
#---exe---#
message " Transformed translated 63x subject and mask images "

if(($CHN>0))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC0TRANS2 -p "#s $SUBSXRECC0TRANS #t $TARTXUSRAW #a $AFFINEMATRIX"
fi

if(($CHN>1))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC1TRANS2 -p "#s $SUBSXRECC1TRANS #t $TARTXUSRAW #a $AFFINEMATRIX"
fi

if(($CHN>2))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC2TRANS2 -p "#s $SUBSXRECC2TRANS #t $TARTXUSRAW #a $AFFINEMATRIX"
fi

if(($CHN>3))
then
$Vaa3D -x ireg -f iwarp -o $SUBSXRECC3TRANS2 -p "#s $SUBSXRECC3TRANS #t $TARTXUSRAW #a $AFFINEMATRIX"
fi

$Vaa3D -x ireg -f iwarp -o $SUBSXMASKRECTRANS2 -p "#s $SUBSXMASKRECTRANS #t $TARTXUSRAW #a $AFFINEMATRIX"
fi

# crop

if(($CHN>0))
then
SUBSXRECC0TRANS2CROP=${OUTPUT}"/subsxREC_c0_translated_transformed_cropped.v3draw"
fi

if(($CHN>1))
then
SUBSXRECC1TRANS2CROP=${OUTPUT}"/subsxREC_c1_translated_transformed_cropped.v3draw"
fi

if(($CHN>2))
then
SUBSXRECC2TRANS2CROP=${OUTPUT}"/subsxREC_c2_translated_transformed_cropped.v3draw"
fi

if(($CHN>3))
then
SUBSXRECC3TRANS2CROP=${OUTPUT}"/subsxREC_c3_translated_transformed_cropped.v3draw"
fi

SUBSXRECRCTRANS2CROP=${OUTPUT}"/subsxREC_c"${SUBSXREF}"_translated_transformed_cropped.v3draw"

TARTXUSRAWCROP=${OUTPUT}"/tartxUS_cropped.v3draw"
TARTXUSRAWCROPCONFIG=${OUTPUT}"/tartxUS_cropped_cropconfigure.txt"
CROPCONFIG=${FINALOUTPUT}"/sxcrop_configure.txt"

if ( is_file_exist "$SUBSXRECRCTRANS2CROP" )
then
echo " SUBSXRECRCTRANS2CROP: $SUBSXRECRCTRANS2CROP exists"
else
#---exe---#
message " Cropping transformed 63x subject images "
$Vaa3D -x ireg -f cropImage -i $TARTXUSRAW -o $TARTXUSRAWCROP -p "#m $SUBSXMASKRECTRANS2"

mv $TARTXUSRAWCROPCONFIG $CROPCONFIG

if(($CHN>0))
then
$Vaa3D -x ireg -f cropImage -i $SUBSXRECC0TRANS2 -o $SUBSXRECC0TRANS2CROP -p "#m $CROPCONFIG"
fi

if(($CHN>1))
then
$Vaa3D -x ireg -f cropImage -i $SUBSXRECC1TRANS2 -o $SUBSXRECC1TRANS2CROP -p "#m $CROPCONFIG"
fi

if(($CHN>2))
then
$Vaa3D -x ireg -f cropImage -i $SUBSXRECC2TRANS2 -o $SUBSXRECC2TRANS2CROP -p "#m $CROPCONFIG"
fi

if(($CHN>3))
then
$Vaa3D -x ireg -f cropImage -i $SUBSXRECC3TRANS2 -o $SUBSXRECC3TRANS2CROP -p "#m $CROPCONFIG"
fi

fi


#
### local alignment
#

### Convert to Nifti Images

TARTXUSCROPNII=${OUTPUT}"/tartxUS_cropped_c0.nii"

if(($CHN>0))
then
SUBSXRECC0TRANS2CROPNII=${OUTPUT}"/subsxREC_c0_translated_transformed_cropped_c0.nii"
fi

if(($CHN>1))
then
SUBSXRECC1TRANS2CROPNII=${OUTPUT}"/subsxREC_c1_translated_transformed_cropped_c0.nii"
fi

if(($CHN>2))
then
SUBSXRECC2TRANS2CROPNII=${OUTPUT}"/subsxREC_c2_translated_transformed_cropped_c0.nii"
fi

if(($CHN>3))
then
SUBSXRECC3TRANS2CROPNII=${OUTPUT}"/subsxREC_c3_translated_transformed_cropped_c0.nii"
fi

SUBSXRECRCTRANS2CROPNII=${OUTPUT}"/subsxREC_c"${SUBSXREF}"_translated_transformed_cropped_c0.nii"

if ( is_file_exist "$TARTXUSCROPNII" )
then
echo " TARTXUSCROPNII: $TARTXUSCROPNII exists"
else
#---exe---#
message " Converting cropped upsampled 20x subject into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $TARTXUSRAWCROP
fi

if ( is_file_exist "$SUBSXRECRCTRANS2CROPNII" )
then
echo " SUBSXRECRCTRANS2CROPNII: $SUBSXRECRCTRANS2CROPNII exists"
else
#---exe---#
message " Converting cropped global aligned 63x subject into Nifti image "

if(($CHN>0))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC0TRANS2CROP
fi

if(($CHN>1))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC1TRANS2CROP
fi

if(($CHN>2))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC2TRANS2CROP
fi

if(($CHN>3))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC3TRANS2CROP
fi

fi

### Downsample

#DSRATIO = 0.4

FIXEDDS=${OUTPUT}"/tartxUS_cropped_c0_ds.nii"
MOVINGDS=${OUTPUT}"/subsxREC_c"${SUBSXREF}"_translated_transformed_croped_c0_ds.nii"

if ( is_file_exist "$FIXEDDS" )
then
echo " FIXEDDS: $FIXEDDS exists"
else
#---exe---#
message " Downsampling cropped upsampled 20x target "
$Vaa3D -x ireg -f resamplebyspacing -i $TARTXUSCROPNII -o $FIXEDDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

if ( is_file_exist "$MOVINGDS" )
then
echo " MOVINGDS: $MOVINGDS exists"
else
#---exe---#
message " Downsampling cropped global aligned 63x subject "
$Vaa3D -x ireg -f resamplebyspacing -i $SUBSXRECRCTRANS2CROPNII -o $MOVINGDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

### local align VOIs

SIMMETRIC=${OUTPUT}"/ccmi"
AFFINEMATRIXLOCAL=${OUTPUT}"/ccmiAffine.txt"
FWDDISPFIELD=${OUTPUT}"/ccmiWarp.nii.gz"
BWDDISPFIELD=${OUTPUT}"/ccmiInverseWarp.nii.gz"

MAXITERSCC=30x90x20

if ( is_file_exist "$AFFINEMATRIXLOCAL" )
then
echo " AFFINEMATRIXLOCAL: $AFFINEMATRIXLOCAL exists"
else
#---exe---#
message " Local alignment "
$ANTS 3 -m  CC[ $FIXEDDS, $MOVINGDS, 0.75, 4] -m MI[ $FIXEDDS, $MOVINGDS, 0.25, 32] -t SyN[0.25]  -r Gauss[3,0] -o $SIMMETRIC -i $MAXITERSCC --initial-affine $INITAFFINE
fi

### warp

if(($CHN>0))
then
SUBSXRECC0TRANS2CROPNIIDFMD=${OUTPUT}"/subsxREC_c0_translated_transformed_croped_c0_deformed.nii"
fi

if(($CHN>1))
then
SUBSXRECC1TRANS2CROPNIIDFMD=${OUTPUT}"/subsxREC_c1_translated_transformed_croped_c0_deformed.nii"
fi

if(($CHN>2))
then
SUBSXRECC2TRANS2CROPNIIDFMD=${OUTPUT}"/subsxREC_c2_translated_transformed_croped_c0_deformed.nii"
fi

if(($CHN>3))
then
SUBSXRECC3TRANS2CROPNIIDFMD=${OUTPUT}"/subsxREC_c3_translated_transformed_croped_c0_deformed.nii"
fi

SUBSXRECRCTRANS2CROPNIIDFMD=${OUTPUT}"/subsxREC_c"${SUBSXREF}"_translated_transformed_croped_c0_deformed.nii"

SUBDeformed=${FINALOUTPUT}"/Aligned63xScale.v3draw"

if ( is_file_exist "$SUBSXRECRCTRANS2CROPNIIDFMD" )
then
echo " SUBSXRECRCTRANS2CROPNIIDFMD: $SUBSXRECRCTRANS2CROPNIIDFMD exists"
else
#---exe---#
message " Warping 63x subject "

if(($CHN>0))
then
$WARP 3 $SUBSXRECC0TRANS2CROPNII $SUBSXRECC0TRANS2CROPNIIDFMD -R $TARTXUSCROPNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>1))
then
$WARP 3 $SUBSXRECC1TRANS2CROPNII $SUBSXRECC1TRANS2CROPNIIDFMD -R $TARTXUSCROPNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>2))
then
$WARP 3 $SUBSXRECC2TRANS2CROPNII $SUBSXRECC2TRANS2CROPNIIDFMD -R $TARTXUSCROPNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>3))
then
$WARP 3 $SUBSXRECC3TRANS2CROPNII $SUBSXRECC3TRANS2CROPNIIDFMD -R $TARTXUSCROPNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

fi

if ( is_file_exist "$SUBDeformed" )
then
echo " SUBDeformed: $SUBDeformed exists"
else
#---exe---#
message " Combining the aligned 63x image channels into one stack "

if(($CHN==1))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC0TRANS2CROPNIIDFMD -o $SUBDeformed -p "#b 1 #v 1"
fi

if(($CHN==2))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC0TRANS2CROPNIIDFMD $SUBSXRECC1TRANS2CROPNIIDFMD -o $SUBDeformed -p "#b 1 #v 1"
fi

if(($CHN==3))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC0TRANS2CROPNIIDFMD $SUBSXRECC1TRANS2CROPNIIDFMD $SUBSXRECC2TRANS2CROPNIIDFMD -o $SUBDeformed -p "#b 1 #v 1"
fi

if(($CHN==4))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBSXRECC0TRANS2CROPNIIDFMD $SUBSXRECC1TRANS2CROPNIIDFMD $SUBSXRECC2TRANS2CROPNIIDFMD $SUBSXRECRCTRANS2CROPNIIDFMD -o $SUBDeformed -p "#b 1 #v 1"
fi

fi

### Warping Neurons

STRN=`echo $SUBSXNEURONS | awk -F\. '{print $1}'`
STRN=`basename $STRN`
STRN=${OUTPUT}/${STRN}
NEUBRAINYFLIP=${STRN}"_yflip.v3draw"

if ( is_file_exist "$NEUBRAINYFLIP" )
then
echo " NEUBRAINYFLIP: $NEUBRAINYFLIP exists"
else
#---exe---#
message " Y-Flipping neurons first "
$Vaa3D -x ireg -f yflip -i $NEUBRAIN -o $NEUBRAINYFLIP
echo ""
fi

NEUBRAINYFLIPREC=${STRN}"_yflip_rec.v3draw"

if ( is_file_exist "$NEUBRAINYFLIPREC" )
then
echo " NEUBRAINYFLIPREC exists"
else
#---exe---#
message " Resizing the neuron "
$Vaa3D -x ireg -f prepare20xData -o $NEUBRAINYFLIPREC -p "#s $NEUBRAINYFLIP #t $SUBTXUSREC #k 1"
fi


NEUBRAINTRANSL=${STRN}"_yflip_rec_transl.v3draw"

if ( is_file_exist "$NEUBRAINTRANSL" )
then
echo " NEUBRAINTRANSL: $NEUBRAINTRANSL exists"
else
#---exe---#
message " Translating Neurons "
$Vaa3D -x ireg -f iwarp -o $NEUBRAINTRANSL -p "#s $NEUBRAINYFLIPREC #t $SUBTXUSREC #a $TCAFFINE #i 1"
echo ""
fi

NEUBRAINTRANSF=${STRN}"_yflip_rec_transf.v3draw"

if ( is_file_exist "$NEUBRAINTRANSF" )
then
echo " NEUBRAINTRANSF: $NEUBRAINTRANSF exists"
else
#---exe---#
message " Transforming Neurons "
$Vaa3D -x ireg -f iwarp -o $NEUBRAINTRANSF -p "#s $NEUBRAINTRANSL #t $SUBTXUSREC #a $AFFINEMATRIX #i 1"
echo ""
fi

NEUBRAINTRANSCROP=${STRN}"_yflip_rec_trans_crop.v3draw"

if ( is_file_exist "$NEUBRAINTRANSCROP" )
then
echo "NEUBRAINTRANSCROP: $NEUBRAINTRANSCROP exists."
else
#---exe---#
message " Cropping Neurons "
$Vaa3D -x ireg -f cropImage -i $NEUBRAINTRANSF -o $NEUBRAINTRANSCROP -p "#m $CROPCONFIG"
echo ""
fi

NEUBRAINTRANSCROPOB=${STRN}"_yflip_rec_trans_crop_8bit.v3draw"

if ( is_file_exist "$NEUBRAINTRANSCROPOB" )
then
echo "NEUBRAINTRANSCROPOB: $NEUBRAINTRANSCROPOB exists."
else
#---exe---#
message " Converting Neurons to 8bit"
$Vaa3D -x ireg -f MultiLabelImageConverter -i $NEUBRAINTRANSCROP -o $NEUBRAINTRANSCROPOB -p "#b 1"
echo ""
fi

NEUBRAINTRANSCROPNII=${STRN}"_yflip_rec_trans_crop_8bit_c0.nii"

if ( is_file_exist "$NEUBRAINTRANSCROPNII" )
then
echo "NEUBRAINTRANSCROPNII: $NEUBRAINTRANSCROPNII exists."
else
#---exe---#
message " Converting cropped Neurons into Nifti "
$Vaa3D -x ireg -f NiftiImageConverter -i $NEUBRAINTRANSCROPOB
echo ""
fi

NEUBRAINDFMD=${OUTPUT}"/NeuronBrainAligned.nii"
NEUBRAINALIGNED=${OUTPUT}"/ConsolidatedLabel63xScale_yflip.v3draw"
NEUBRAINALIGNEDYFLIP=${FINALOUTPUT}"/ConsolidatedLabel63xScale.v3draw"

if ( is_file_exist "$NEUBRAINALIGNED" )
then
echo " NEUBRAINALIGNED: $NEUBRAINALIGNED exists"
else
#---exe---#
message " Warping Neurons "
#$WARPMT -d 3 -i $NEUBRAINTRANSCROPNII -r $TARTXUSCROPNII -n MultiLabel[0.8x0.8x0.8vox,4.0] -t $AFFINEMATRIXLOCAL -t $FWDDISPFIELD -o $NEUBRAINDFMD
$WARP 3 $NEUBRAINTRANSCROPNII $NEUBRAINDFMD -R $TARTXUSCROPNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-NN
$Vaa3D -x ireg -f NiftiImageConverter -i $NEUBRAINDFMD -o $NEUBRAINALIGNED -p "#b 1 #v 2 #r 0"
echo ""
fi

if ( is_file_exist "$NEUBRAINALIGNEDYFLIP" )
then
echo " NEUBRAINALIGNEDYFLIP: $NEUBRAINALIGNEDYFLIP exists"
else
#---exe---#
message " Y-Flipping neurons back "
$Vaa3D -x ireg -f yflip -i $NEUBRAINALIGNED -o $NEUBRAINALIGNEDYFLIP
echo ""
fi


##################
# 20x scale result
##################

### padding zeros

SUBDeformedZeropad=${OUTPUT}"/subsxDeformed_zeropadded.v3draw"
NEUDeformedZeropad=${OUTPUT}"/neusxDeformed_zeropadded.v3draw"

if ( is_file_exist "$SUBDeformedZeropad" )
then
echo " SUBDeformedZeropad: $SUBDeformedZeropad exists"
else
#---exe---#
message " Padding zeros "
$Vaa3D -x ireg -f zeropadding -i $SUBDeformed -o $SUBDeformedZeropad -p "#c $CROPCONFIG"
fi

if ( is_file_exist "$NEUDeformedZeropad" )
then
echo " NEUDeformedZeropad: $NEUDeformedZeropad exists"
else
#---exe---#
message " Padding zeros "
$Vaa3D -x ireg -f zeropadding -i $NEUBRAINALIGNED -o $NEUDeformedZeropad -p "#c $CROPCONFIG"
fi

### resize

SUBDeformedZeropadTX=${OUTPUT}"/subsxDeformed_zeropadded_cnvt20xscale.v3draw"
SUBDeformedTX=${FINALOUTPUT}"/Aligned20xScale.v3draw"

SRS2TZ=`echo $SRS2TZ/1.44 | bc -l`

if ( is_file_exist "$SUBDeformedTX" )
then
echo " SUBDeformedTX: $SUBDeformedTX exists"
else
#---exe---#
message " Resizing to 20x scale "
$Vaa3D -x ireg -f isampler -i $SUBDeformedZeropad -o $SUBDeformedZeropadTX -p "#x $SRS2TX #y $SRS2TY #z $SRS2TZ"
$Vaa3D -x ireg -f prepare20xData -o $SUBDeformedTX -p "#s $SUBDeformedZeropadTX #t $ATLAS"
fi


NEUDeformedZeropadTX=${OUTPUT}"/neusxDeformed_zeropadded_cnvt20xscale.v3draw"
NEUDeformedTX=${OUTPUT}"/ConsolidatedLabel20xScale_yflip.v3draw"
NEUDeformedTXYFLIP=${FINALOUTPUT}"/ConsolidatedLabel20xScale.v3draw"

if ( is_file_exist "$NEUDeformedTX" )
then
echo " NEUDeformedTX: $NEUDeformedTX exists"
else
#---exe---#
message " Resizing Neuron to 20x scale "
$Vaa3D -x ireg -f isampler -i $NEUDeformedZeropad -o $NEUDeformedZeropadTX -p "#x $SRS2TX #y $SRS2TY #z $SRS2TZ #i 1"
$Vaa3D -x ireg -f prepare20xData -o $NEUDeformedTX -p "#s $NEUDeformedZeropadTX #t $ATLAS #k 1"
fi

if ( is_file_exist "$NEUDeformedTXYFLIP" )
then
echo " NEUDeformedTXYFLIP: $NEUDeformedTXYFLIP exists"
else
#---exe---#
message " Y-Flipping neurons back "
$Vaa3D -x ireg -f yflip -i $NEUDeformedTX -o $NEUDeformedTXYFLIP
echo ""
fi

##################
# Evaluation
##################

message " Generating Verification Movie "
ALIGNVERIFY=AlignVerify.mp4
$DIR/createVerificationMovie.sh -c $CONFIGFILE -k $TOOLDIR -w $WORKDIR -s $SUBDeformed -i $TARTXUSRAWCROP -r $((SUBSXREF+1)) -o ${FINALOUTPUT}/$ALIGNVERIFY

##################
# evalutation
##################

AQ=${OUTPUT}"/AlignmentQuality.txt"

SUBSXREF=$((SUBSXREF+1))

if ( is_file_exist "$AQ" )
then
echo " AQ exists"
else
#---exe---#
message " Evaluating "
$Vaa3D -x ireg -f esimilarity -o $AQ -p "#s $SUBDeformedTX #cs $SUBSXREF #t $ATLAS"
fi

while read LINE
do
read SCORE
done < $AQ; 

##################
# Output Meta
##################

if [[ -f "$SUBDeformedTX" ]]; then
META=${FINALOUTPUT}"/Aligned20xScale.properties"
echo "alignment.stack.filename=Aligned20xScale.v3draw" >> $META
echo "alignment.image.channels=$INPUT2_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT2_REF" >> $META
echo "alignment.space.name=$UNIFIED_SPACE" >> $META
echo "alignment.resolution.voxels=${RESTX_X_IS}x${RESTX_Y_IS}x${RESTX_Z_IS}" >> $META
echo "alignment.image.size=1024x512x218" >> $META
echo "alignment.objective=20x" >> $META
echo "alignment.quality.score.ncc=$SCORE" >> $META
if [[ -f "$NEUDeformedTXYFLIP" ]]; then
echo "neuron.masks.filename=ConsolidatedLabel20xScale.v3draw" >> $META
fi
fi

if [[ -f "$SUBDeformed" ]]; then
META=${FINALOUTPUT}"/Aligned63xScale.properties"
echo "alignment.stack.filename=Aligned63xScale.v3draw" >> $META
echo "alignment.image.channels=$INPUT1_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT1_REF" >> $META
echo "alignment.space.name=$UNIFIED_SPACE" >> $META
echo "alignment.resolution.voxels=${RESSX_X}x${RESSX_Y}x${RESSX_Z}" >> $META
echo "alignment.image.size=" >> $META
echo "alignment.bounding.box=" >> $META
echo "alignment.objective=63x" >> $META
if [[ -f "$NEUBRAINALIGNEDYFLIP" ]]; then
echo "neuron.masks.filename=ConsolidatedLabel63xScale.v3draw" >> $META
fi
echo "default=true" >> $META
fi

