#!/bin/bash
#
# fly brain alignment pipeline for polarity pair, version 2.0, May 30, 2013
#

################################################################################
#
# Voxel Size: (63x) 0.38x0.38x0.38 (20x) 0.46x0.46x0.46
# Upsampling ratio  : 1.2227x1.2227x2.00 (20x -> 63x) Then resize image.
# Dimensions : (63x) 1450x725x436  (20x) 1184x592x218
# Dims("rec"): (63x) 1565x1252x512 (20x) 1280x1024x256
### Downsampling ratio: 0.8166x0.8166x0.5 (63x -> 20x)
# Downsampling ratio: 0.8179x0.8179x0.5 (63x -> 20x)
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
RESSX=$INPUT1_RESX
RESSY=$INPUT1_RESY
RESSZ=$INPUT1_RESZ
CHN=$INPUT1_CHANNELS

# 20x parameters
SUBTX=$INPUT2_FILE
SUBTXREF=$INPUT2_REF
SUBTXNEURONS=$INPUT2_NEURONS
RESTX=$INPUT2_RESX
RESTY=$INPUT2_RESY
RESTZ=$INPUT2_RESZ

# tools
Vaa3D=`readItemFromConf $CONFIGFILE "Vaa3D"`
JBA=`readItemFromConf $CONFIGFILE "JBA"`
ANTS=`readItemFromConf $CONFIGFILE "ANTS"`
WARP=`readItemFromConf $CONFIGFILE "WARP"`

Vaa3D=${TOOLDIR}"/"${Vaa3D}
JBA=${TOOLDIR}"/"${JBA}
ANTS=${TOOLDIR}"/"${ANTS}
WARP=${TOOLDIR}"/"${WARP}

# templates
TARREF=`readItemFromConf $CONFIGFILE "REFNO"`

TARTX=`readItemFromConf $CONFIGFILE "tgtFBTXDPX"`
TARSX=`readItemFromConf $CONFIGFILE "tgtFBSXDPXSS"`
TARTXEXT=`readItemFromConf $CONFIGFILE "tgtFBTXRECDPX"`
TARSXEXT=`readItemFromConf $CONFIGFILE "tgtFBSXRECDPXSS"`

RESTX_X=`readItemFromConf $CONFIGFILE "VSZX_20X_IS_DPX"`
RESTX_Y=`readItemFromConf $CONFIGFILE "VSZY_20X_IS_DPX"`
RESTX_Z=`readItemFromConf $CONFIGFILE "VSZZ_20X_IS_DPX"`

RESSX_X=`readItemFromConf $CONFIGFILE "VSZX_63X_IS"`
RESSX_Y=`readItemFromConf $CONFIGFILE "VSZY_63X_IS"`
RESSX_Z=`readItemFromConf $CONFIGFILE "VSZZ_63X_IS"`

INITAFFINE=`readItemFromConf $CONFIGFILE "IDENTITYMATRIX"`

TARTX=${TMPLDIR}"/"${TARTX}
TARSX=${TMPLDIR}"/"${TARSX}
TARTXEXT=${TMPLDIR}"/"${TARTXEXT}
TARSXEXT=${TMPLDIR}"/"${TARSXEXT}
INITAFFINE=${TMPLDIR}"/"${INITAFFINE}

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "TMPLDIR: $TMPLDIR"
echo "TOOLDIR: $TOOLDIR"
echo "WORKDIR: $WORKDIR"

echo "MountingProtocol: $MP"

echo "SUBSX: $SUBSX"
echo "SUBSXREF: $SUBSXREF"
echo "SUBSXNEURONS: $SUBSXNEURONS"
echo "RESSX: $RESSX"
echo "RESSY: $RESSY"
echo "RESSZ: $RESSZ"
echo "CHN: $CHN"

echo "SUBTX: $SUBTX"
echo "SUBTXREF: $SUBTXREF"
echo "SUBTXNEURONS: $SUBTXNEURONS"
echo "RESTX: $RESTX"
echo "RESTY: $RESTY"
echo "RESTZ: $RESTZ"

message "Vars..."
echo "Vaa3D: $Vaa3D"
echo "ANTS: $ANTS"
echo "WARP: $WARP"

echo "TARTX: $TARTX"
echo "TARSX: $TARSX"
echo "TARREF: $TARREF"
echo "TARTXEXT: $TARTXEXT"
echo "TARSXEXT: $TARSXEXT"

echo "RESTX_X: $RESTX_X"
echo "RESTX_Y: $RESTX_Y"
echo "RESTX_Z: $RESTX_Z"

echo "RESSX_X: $RESSX_X"
echo "RESSX_Y: $RESSX_Y"
echo "RESSX_Z: $RESSX_Z"

echo "INITAFFINE: $INITAFFINE"

echo ""

# convert inputs to raw format
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUBSX" SUBSX
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUBTX" SUBTX
echo "RAW SUB SX: $SUBSX"
echo "RAW SUB TX: $SUBTX"
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUBSXNEURONS" SUBSXNEURONS
echo "RAW SUBSXNEURONS: $SUBSXNEURONS"

OUTPUT=${WORKDIR}"/Outputs"
FINALOUTPUT=${WORKDIR}"/FinalOutputs"

if [ ! -d $OUTPUT ]; then 
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then 
mkdir $FINALOUTPUT
fi

#############

TARSXEXTDX=1565
TARSXEXTDY=1252
TARSXEXTDZ=512

SRSTX=0.8179
SRSTY=0.8179
SRSTZ=0.5

SRTSX=1.2227
SRTSY=1.2227
SRTSZ=2.0

#############

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

TEMPTARGET=${OUTPUT}"/temptargetsx.v3draw"
if ( is_file_exist "$TEMPTARGET" )
then
echo "TEMPTARGET: $TEMPTARGET exists"
else
#---exe---#
message " Creating a symbolic link to 63x target "
ln -s ${TARSX} ${TEMPTARGET}
fi
TARSX=$TEMPTARGET

TEMPTARGET=${OUTPUT}"/temptargettxext.v3draw"
if ( is_file_exist "$TEMPTARGET" )
then
echo "TEMPTARGET: $TEMPTARGET exists"
else
#---exe---#
message " Creating a symbolic link to 63x target "
ln -s ${TARTXEXT} ${TEMPTARGET}
fi
TARTXEXT=$TEMPTARGET

TEMPTARGET=${OUTPUT}"/temptargetsxext.v3draw"
if ( is_file_exist "$TEMPTARGET" )
then
echo "TEMPTARGET: $TEMPTARGET exists"
else
#---exe---#
message " Creating a symbolic link to 63x target "
ln -s ${TARSXEXT} ${TEMPTARGET}
fi
TARSXEXT=$TEMPTARGET

### temporary subject
TEMPSUBJECT=${OUTPUT}"/tempsubjecttx.v3draw"
if ( is_file_exist "$TEMPSUBJECT" )
then
echo "TEMPSUBJECT: $TEMPSUBJECT exists"
else
#---exe---#
message " Creating a symbolic link to 20x subject "
ln -s ${SUBTX} ${TEMPSUBJECT}
fi
SUBTX=$TEMPSUBJECT

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

#############

# FIXED TX
TARTXNII=${OUTPUT}"/temptargettxext_c0.nii"
if ( is_file_exist "$TARTXNII" )
then
echo " TARTXNII: $TARTXNII exists"
else
#---exe---#
message " Converting 20x target into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $TARTXEXT
fi

# MOVING TX
SUBTXRFC=${OUTPUT}"/subtxRefChn.v3draw"
if ( is_file_exist "$SUBTXRFC" )
then
echo " SUBTXRFC: $SUBTXRFC exists"
else
#---exe---#
message " Extracting the reference of the 20x subject "
$Vaa3D -x refExtract -f refExtract -i $SUBTX -o $SUBTXRFC -p "#c $SUBTXREF";
fi

# sampling 20x subject if the voxel size is not the same to the 20x target

ISRX=`echo $RESTX/$RESTX_X | bc -l`
ISRY=`echo $RESTY/$RESTX_Y | bc -l`
ISRZ=`echo $RESTZ/$RESTX_Z | bc -l`

SRXC=$(bc <<< "$ISRX - 1.0")
SRYC=$(bc <<< "$ISRY - 1.0")
SRZC=$(bc <<< "$ISRZ - 1.0")

ASRXC=`echo $SRXC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
ASRYC=`echo $SRYC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
ASRZC=`echo $SRZC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`

SUBTXIS=${OUTPUT}"/subtxRefChnIS.v3draw"
if [ $(bc <<< "$ASRXC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRYC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRZC < 0.01") -eq 1 ]; then

message " The resolution of the 20x subject is the same to the 20x target "
ln -s $SUBTXRFC $SUBTXIS

else

if ( is_file_exist "$SUBTXIS" )
then
echo " SUBTXIS: $SUBTXIS exists"
else
#---exe---#
message " Isotropic sampling 20x subject "
$Vaa3D -x ireg -f isampler -i $SUBTXRFC -o $SUBTXIS -p "#x $ISRX #y $ISRY #z $ISRZ"
fi

fi

# SUBTXRFCRS -> affine -> non-rigid -> translation
SUBTXRFCRS=${OUTPUT}"/subtxRefChnRs.v3draw"
if ( is_file_exist "$SUBTXRFCRS" )
then
echo " SUBTXRFCRS: $SUBTXRFCRS exists"
else
#---exe---#
message " Resizing the 20x subject to 20x target "
$Vaa3D -x ireg -f prepare20xData -o $SUBTXRFCRS -p "#s $SUBTXIS #t $TARTXEXT"
fi

# MOVING SX

# sampling 63x subject if the voxel size is not the same to the 63x target

ISRX=`echo $RESSX/$RESSX_X | bc -l`
ISRY=`echo $RESSY/$RESSX_Y | bc -l`
ISRZ=`echo $RESSZ/$RESSX_Z | bc -l`

SRXC=$(bc <<< "$ISRX - 1.0")
SRYC=$(bc <<< "$ISRY - 1.0")
SRZC=$(bc <<< "$ISRZ - 1.0")

ASRXC=`echo $SRXC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
ASRYC=`echo $SRYC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
ASRZC=`echo $SRZC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`

SUBSXIS=${OUTPUT}"/subsxIS.v3draw"
if [ $(bc <<< "$ASRXC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRYC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRZC < 0.01") -eq 1 ]; then

message " The resolution of the 63x subject is the same to the 63x target "
ln -s $SUBSX $SUBSXIS

else

if ( is_file_exist "$SUBSXIS" )
then
echo " SUBSXIS: $SUBSXIS exists"
else
#---exe---#
message " Isotropic sampling 63x subject "
$Vaa3D -x ireg -f isampler -i $SUBSX -o $SUBSXIS -p "#x $ISRX #y $ISRY #z $ISRZ"
fi

fi

SUBSXRS=${OUTPUT}"/subsxRs.v3draw"
if ( is_file_exist "$SUBSXRS" )
then
echo " SUBSXRS: $SUBSXRS exists"
else
#---exe---#
message " Resizing the 63x subject to 63x target "
$Vaa3D -x ireg -f prepare20xData -o $SUBSXRS -p "#s $SUBSXIS #t $TARSXEXT"
fi

SUBSXRSRFC=${OUTPUT}"/subsxRsRefChn.v3draw"
if ( is_file_exist "$SUBSXRSRFC" )
then
echo " SUBSXRSRFC: $SUBSXRSRFC exists"
else
#---exe---#
message " Extracting the reference of the 63x subject "
$Vaa3D -x refExtract -f refExtract -i $SUBSXRS -o $SUBSXRSRFC -p "#c $SUBSXREF";
fi

# SUBSXRSRFCDS -> translation
SUBSXRSRFCDS=${OUTPUT}"/subsxRsRefChnDs.v3draw"
if ( is_file_exist "$SUBSXRSRFCDS" )
then
echo " SUBSXRSRFCDS: $SUBSXRSRFCDS exists"
else
#---exe---#
message " Downsampling the reference of the 63x subject "
$Vaa3D -x ireg -f isampler -i $SUBSXRSRFC -o $SUBSXRSRFCDS -p "#x $SRSTX #y $SRSTY #z $SRSTZ";
fi


# 63x mask
SUBSXMASK=${OUTPUT}"/subsxMask.v3draw"
if ( is_file_exist "$SUBSXMASK" )
then
echo " SUBSXMASK: $SUBSXMASK exists"
else
#---exe---#
message " Creating a mask image for the 63x subject "
$Vaa3D -x ireg -f createMaskImage -i $SUBSXIS -o $SUBSXMASK
fi

SUBSXMASKRS=${OUTPUT}"/subsxMaskRs.v3draw"
if ( is_file_exist "$SUBSXMASKRS" )
then
echo " SUBSXMASKRS: $SUBSXMASKRS exists"
else
#---exe---#
message " Resizing the 63x mask to 63x target "
$Vaa3D -x ireg -f prepare20xData -o $SUBSXMASKRS -p "#s $SUBSXMASK #t $TARSXEXT"
fi


# MOVING TX
SUBTXNII=${OUTPUT}"/subtxRefChnRs_c0.nii"
if ( is_file_exist "$SUBTXNII" )
then
echo " SUBTXNII: $SUBTXNII exists"
else
#---exe---#
message " Converting 20x subject into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBTXRFCRS
fi


#############

#
### global alignment
#

message " Global alignment "

MAXITERATIONS=10000x10000x10000x10000

### 1) global align $SUBTX to $TARTX

SIMMETRIC=${OUTPUT}"/txmi"
AFFINEMATRIX=${OUTPUT}"/txmiAffine.txt"

if ( is_file_exist "$AFFINEMATRIX" )
then
echo " AFFINEMATRIX: $AFFINEMATRIX exists"
else
#---exe---#
message " Global aligning 20x subject to 20x target "
$ANTS 3 -m  MI[ $TARTXNII, $SUBTXNII, 1, 32] -o $SIMMETRIC -i 0 --number-of-affine-iterations $MAXITERATIONS --rigid-affine true
fi

### 2) match downsampled $SUBSX to $SUBTX

STITCHFOLDER=${OUTPUT}"/stitch"

if [ ! -d $STITCHFOLDER ]; then 
mkdir $STITCHFOLDER
fi

TCFILE=$STITCHFOLDER"/stitched_image.tc"
TCTEXT=$STITCHFOLDER"/stitched_image.txt"
TCAFFINE=$OUTPUT"/translations.txt"
SUBSXFORSTITCH=$STITCHFOLDER"/subsx.v3draw"
SUBTXFORSTITCH=$STITCHFOLDER"/subtx.v3draw"

if ( is_file_exist "$SUBTXFORSTITCH" )
then
echo " SUBTXFORSTITCH: $SUBTXFORSTITCH exists"
else
#---exe---#
message " Creating symbolic link for stitching "
ln -s $SUBTXRFCRS $SUBTXFORSTITCH
fi

if ( is_file_exist "$SUBSXFORSTITCH" )
then
echo " SUBSXFORSTITCH: $SUBSXFORSTITCH exists"
else
#---exe---#
message " Creating symbolic link for stitching "
ln -s $SUBSXRSRFCDS $SUBSXFORSTITCH
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
$Vaa3D -x ireg -f convertTC2AM -i $TCTEXT -o $TCAFFINE -p "#x $SRTSX #y $SRTSY #z $SRTSZ"
fi

#############

#
### local alignment
#

SUBSXRSTL=${OUTPUT}"/subsxRsTranslated.v3draw"
if ( is_file_exist "$SUBSXRSTL" )
then
echo " SUBSXRSTL: $SUBSXRSTL exists"
else
#---exe---#
message " Translating recentered 63x subject "
$Vaa3D -x ireg -f iwarp2 -o $SUBSXRSTL -p "#s $SUBSXRS #a $TCAFFINE #dx $TARSXEXTDX #dy $TARSXEXTDY #dz $TARSXEXTDZ"
fi

SUBSXRSTLTF=${OUTPUT}"/subsxRsTranslatedTransformed.v3draw"
if ( is_file_exist "$SUBSXRSTLTF" )
then
echo " SUBSXRSTLTF: $SUBSXRSTLTF exists"
else
#---exe---#
message " Transforming translated 63x subject "
$Vaa3D -x ireg -f iwarp2 -o $SUBSXRSTLTF -p "#s $SUBSXRSTL #a $AFFINEMATRIX #sx $SRTSX #sy $SRTSY #sz $SRTSZ #dx $TARSXEXTDX #dy $TARSXEXTDY #dz $TARSXEXTDZ"
fi

### mask

SUBSXMASKRSTL=${OUTPUT}"/subsxMaskRsTranslated.v3draw"
if ( is_file_exist "$SUBSXMASKRSTL" )
then
echo " SUBSXMASKRSTL: $SUBSXMASKRSTL exists"
else
#---exe---#
message " Translating recentered 63x mask "
$Vaa3D -x ireg -f iwarp2 -o $SUBSXMASKRSTL -p "#s $SUBSXMASKRS #a $TCAFFINE #dx $TARSXEXTDX #dy $TARSXEXTDY #dz $TARSXEXTDZ"
fi

SUBSXMASKRSTLTF=${OUTPUT}"/subsxMaskRsTranslatedTransformed.v3draw"
if ( is_file_exist "$SUBSXMASKRSTLTF" )
then
echo " SUBSXMASKRSTLTF: $SUBSXMASKRSTLTF exists"
else
#---exe---#
message " Transforming translated 63x mask "
$Vaa3D -x ireg -f iwarp2 -o $SUBSXMASKRSTLTF -p "#s $SUBSXMASKRSTL #a $AFFINEMATRIX #sx $SRTSX #sy $SRTSY #sz $SRTSZ #dx $TARSXEXTDX #dy $TARSXEXTDY #dz $TARSXEXTDZ"
fi

### crop image

TARSXCROP=${OUTPUT}"/temptargetsx_cropped.v3draw"
TARSXCROPCONFIG=${OUTPUT}"/temptargetsx_cropped_cropconfigure.txt"
if ( is_file_exist "$TARSXCROP" )
then
echo " TARSXCROP: $TARSXCROP exists"
else
#---exe---#
message " Cropping transformed 63x subject images "
$Vaa3D -x ireg -f cropImage -i $TARSXEXT -o $TARSXCROP -p "#m $SUBSXMASKRSTLTF"
fi

#SUBSXRSTLTFCROP=${OUTPUT}"/subsxRsTranslatedTransformedRs_cropped.v3draw"
SUBSXRSTLTFCROP=${OUTPUT}"/subjectGlobalAligned63xScale.v3draw"
if ( is_file_exist "$SUBSXRSTLTFCROP" )
then
echo " SUBSXRSTLTFCROP: $SUBSXRSTLTFCROP exists"
else
#---exe---#
message " Cropping transformed 63x subject images "
$Vaa3D -x ireg -f cropImage -i $SUBSXRSTLTF -o $SUBSXRSTLTFCROP -p "#m $TARSXCROPCONFIG"
fi

FIXEDRAW=${OUTPUT}"/targetvoi63x.v3draw"
if ( is_file_exist "$FIXEDRAW" )
then
echo " FIXEDRAW: $FIXEDRAW exists"
else
#---exe---#
ln -s $TARSXCROP $FIXEDRAW
fi

MOVINGRAW=${OUTPUT}"/subjectvoi63x.v3draw"
if ( is_file_exist "$MOVINGRAW" )
then
echo " MOVINGRAW: $MOVINGRAW exists"
else
#---exe---#
ln -s $SUBSXRSTLTFCROP $MOVINGRAW
fi

FIXEDNII=${OUTPUT}"/targetvoi63x_c0.nii"
if ( is_file_exist "$FIXEDNII" )
then
echo " FIXEDNII: $FIXEDNII exists"
else
#---exe---#
message " Converting 63x target VOI into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $FIXEDRAW
fi

if(($CHN>0))
then
MOVINGNIICI=${OUTPUT}"/subjectvoi63x_c0.nii"
fi

if(($CHN>1))
then
MOVINGNIICII=${OUTPUT}"/subjectvoi63x_c1.nii"
fi

if(($CHN>2))
then
MOVINGNIICIII=${OUTPUT}"/subjectvoi63x_c2.nii"
fi

if(($CHN>3))
then
MOVINGNIICIV=${OUTPUT}"/subjectvoi63x_c3.nii"
fi

SUBSXREF_ZEROIDX=$((SUBSXREF-1));
MOVINGNIICR=${OUTPUT}"/subjectvoi63x_c"${SUBSXREF_ZEROIDX}".nii"
if ( is_file_exist "$MOVINGNIICR" )
then
echo " MOVINGNIICR: $MOVINGNIICR exists"
else
#---exe---#
message " Converting 63x subject VOI into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGRAW
fi

DSRATIO=0.5
FIXEDDS=${OUTPUT}"/targetvoi_ds.nii"
MOVINGDS=${OUTPUT}"/subjectvoi_ds.nii"

if ( is_file_exist "$FIXEDDS" )
then
echo " FIXEDDS: $FIXEDDS exists"
else
#---exe---#
message " Downsampling 63x target voi "
echo $Vaa3D -x ireg -f resamplebyspacing -i $FIXEDNII -o $FIXEDDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
$Vaa3D -x ireg -f resamplebyspacing -i $FIXEDNII -o $FIXEDDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

if ( is_file_exist "$MOVINGDS" )
then
echo " MOVINGDS: $MOVINGDS exists"
else
#---exe---#
message " Downsampling 63x subject voi "
echo $Vaa3D -x ireg -f resamplebyspacing -i $MOVINGNIICR -o $MOVINGDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
$Vaa3D -x ireg -f resamplebyspacing -i $MOVINGNIICR -o $MOVINGDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi


# local alignment

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

#############
# warping
#############

if(($CHN>0))
then
MOVINGDFRMDCI=${OUTPUT}"/subjectvoi63x_c0_deformed.nii"
fi

if(($CHN>1))
then
MOVINGDFRMDCII=${OUTPUT}"/subjectvoi63x_c1_deformed.nii"
fi

if(($CHN>2))
then
MOVINGDFRMDCIII=${OUTPUT}"/subjectvoi63x_c2_deformed.nii"
fi

if(($CHN>3))
then
MOVINGDFRMDCIV=${OUTPUT}"/subjectvoi63x_c3_deformed.nii"
fi

MOVINGDFRMDCR=${OUTPUT}"/subjectvoi63x_c"${SUBSXREF_ZEROIDX}"_deformed.nii"

SUBSXDFRMD=${OUTPUT}"/subjectLocalAligned63xScale.v3draw"

if ( is_file_exist "$MOVINGDFRMDCR" )
then
echo " MOVINGDFRMDCR: $MOVINGDFRMDCR exists"
else
#---exe---#
message " Warping 63x subject "

if(($CHN>0))
then
$WARP 3 $MOVINGNIICI $MOVINGDFRMDCI -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>1))
then
$WARP 3 $MOVINGNIICII $MOVINGDFRMDCII -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>2))
then
$WARP 3 $MOVINGNIICIII $MOVINGDFRMDCIII -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>3))
then
$WARP 3 $MOVINGNIICIV $MOVINGDFRMDCIV -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

fi

if ( is_file_exist "$SUBSXDFRMD" )
then
echo " SUBSXDFRMD: $SUBSXDFRMD exists"
else
#---exe---#
message " Combining the aligned 63x image channels into one stack "

if(($CHN==1))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI -o $SUBSXDFRMD -p "#b 1 #v 1"
fi

if(($CHN==2))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI $MOVINGDFRMDCII -o $SUBSXDFRMD -p "#b 1 #v 1"
fi

if(($CHN==3))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI $MOVINGDFRMDCII $MOVINGDFRMDCIII -o $SUBSXDFRMD -p "#b 1 #v 1"
fi

if(($CHN==4))
then
$Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI $MOVINGDFRMDCII $MOVINGDFRMDCIII $MOVINGDFRMDCIV -o $SUBSXDFRMD -p "#b 1 #v 1"
fi

fi

#############

# whole brain space

SUBSXWBS=${OUTPUT}"/subsxAlignedWholeBrainSpace.v3draw"
SUBSXALINGED=${FINALOUTPUT}"/Aligned63xScale.v3draw"

if ( is_file_exist "$SUBSXWBS" )
then
echo " SUBSXWBS: $SUBSXWBS exists"
else
#---exe---#
message " Padding zeros "
$Vaa3D -x ireg -f zeropadding -i $SUBSXDFRMD -o $SUBSXWBS -p "#c $TARSXCROPCONFIG"
fi

if ( is_file_exist "$SUBSXALINGED" )
then
echo " SUBSXALINGED: $SUBSXALINGED exists"
else
#---exe---#
message " Resizing the 63x subject to 63x target "
$Vaa3D -x ireg -f prepare20xData -o $SUBSXALINGED -p "#s $SUBSXWBS #t $TARSX"
fi

# keep all the transformations

AFFINEMATRIXSAVE=${FINALOUTPUT}"/txmiAffine.txt"
TCAFFINESAVE=${FINALOUTPUT}"/translations.txt"
FWDDISPFIELDSAVE=${FINALOUTPUT}"/ccmiWarp.nii.gz"
BWDDISPFIELDSAVE=${FINALOUTPUT}"/ccmiInverseWarp.nii.gz"
AFFINEMATRIXLOCALSAVE=${FINALOUTPUT}"/ccmiAffine.txt"

mv $AFFINEMATRIX $AFFINEMATRIXSAVE

mv $TCAFFINE $TCAFFINESAVE

mv $FWDDISPFIELD $FWDDISPFIELDSAVE
mv $BWDDISPFIELD $BWDDISPFIELDSAVE

mv $AFFINEMATRIXLOCAL $AFFINEMATRIXLOCALSAVE

message " Generating Verification Movie "
ALIGNVERIFY=VerifyMovie.mp4
$DIR/createVerificationMovie.sh -c $CONFIGFILE -k $TOOLDIR -w $WORKDIR -s $SUBSXALINGED -i $TARSX -r $SUBSXREF -o ${FINALOUTPUT}/$ALIGNVERIFY

##################
# Output Meta
##################

if [[ -f "$SUBSXALINGED" ]]; then
META=${FINALOUTPUT}"/Aligned63xScale.properties"
echo "alignment.stack.filename=Aligned63xScale.v3draw" >> $META
echo "alignment.image.channels=$INPUT1_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT1_REF" >> $META
echo "alignment.verify.filename=${ALIGNVERIFY}" >> $META
echo "alignment.space.name=Yoshi 63x Subsampled Alignment Space" >> $META
echo "alignment.resolution.voxels=${RESSX_X}x${RESSX_Y}x${RESSX_Z}" >> $META
echo "alignment.image.size=1450x725x436" >> $META
echo "alignment.bounding.box=" >> $META
echo "alignment.objective=63x" >> $META
echo "default=true" >> $META
fi

