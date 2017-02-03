#!/bin/bash
#
# fly alignment pipeline, version 1.0, 2013/2/15
#

################################################################################
#
# The pipeline is developed for aligning 20x fly (brain + VNC).
# Target brain's resolution (0.62x0.62x0.62 um)
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
SUBBRAIN=$INPUT1_FILE
SUBVNC=$INPUT2_FILE
SUBREF=$INPUT1_REF
MP=$MOUNTING_PROTOCOL
NEUBRAIN=$INPUT1_NEURONS
NEUVNC=$INPUT2_NEURONS
RESX=$INPUT1_RESX
RESY=$INPUT1_RESY
RESZ=$INPUT1_RESZ
VNCRES="${INPUT2_RESX}x${INPUT2_RESY}x${INPUT2_RESZ}"
DIMX=$INPUT2_DIMX
DIMY=$INPUT2_DIMY
DIMZ=$INPUT2_DIMZ
VNCDIMS="${DIMX}x${DIMY}x${DIMZ}"

# tools
Vaa3D=`readItemFromConf $CONFIGFILE "Vaa3D"`
JBA=`readItemFromConf $CONFIGFILE "JBA"`
ANTS=`readItemFromConf $CONFIGFILE "ANTS"`
WARP=`readItemFromConf $CONFIGFILE "WARP"`
WARPMT=`readItemFromConf $CONFIGFILE "WARPMT"`

Vaa3D=${TOOLDIR}"/"${Vaa3D}
ANTS=${TOOLDIR}"/"${ANTS}
WARP=${TOOLDIR}"/"${WARP}
WARPMT=${TOOLDIR}"/"${WARPMT}

# templates
ATLAS=`readItemFromConf $CONFIGFILE "atlasFBTX"`
TAR=`readItemFromConf $CONFIGFILE "tgtFBRCTX"`
TARREF=`readItemFromConf $CONFIGFILE "REFNO"`
RESTX_X=`readItemFromConf $CONFIGFILE "VSZX_20X_IS"`
RESTX_Y=`readItemFromConf $CONFIGFILE "VSZY_20X_IS"`
RESTX_Z=`readItemFromConf $CONFIGFILE "VSZZ_20X_IS"`

TAR=${TMPLDIR}"/"${TAR}
ATLAS=${TMPLDIR}"/"${ATLAS}
INITAFFINE=${TMPLDIR}"/"${INITAFFINE}

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "WORKDIR: $WORKDIR"
echo "SUBBRAIN: $SUBBRAIN"
echo "SUBVNC: $SUBVNC"
echo "SUBREF: $SUBREF"
echo "MountingProtocol: $MP"
echo "NEUBRAIN: $NEUBRAIN"
echo "NEUVNC: $NEUVNC"
message "Vars..."
echo "Vaa3D: $Vaa3D"
echo "ANTS: $ANTS"
echo "WARP: $WARP"
echo "WARPMT: $WARPMT"
echo "TAR: $TAR"
echo "TARREF: $TARREF"
echo "ATLAS: $ATLAS"
echo "RESX: $RESX"
echo "RESY: $RESY"
echo "RESZ: $RESZ"
echo "DIMX (VNC): $DIMX"
echo "DIMY (VNC): $DIMY"
echo "DIMZ (VNC): $DIMZ"
echo ""

OUTPUT=${WORKDIR}"/tmp"
FINALOUTPUT=${WORKDIR}"/FinalOutputs"

if [ ! -d $OUTPUT ]; then 
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then 
mkdir $FINALOUTPUT
fi

ensureRawFileWdiffName "$Vaa3D" "$OUTPUT" "$NEUBRAIN" "${NEUBRAIN%.*}_Brain.v3draw" NEUBRAIN
echo "RAW NEUBRAIN: $NEUBRAIN"

ensureRawFileWdiffName "$Vaa3D" "$OUTPUT" "$NEUVNC" "${NEUVNC%.*}_VNC.v3draw" NEUVNC
echo "RAW NEUVNC: $NEUVNC"

##################
# Preprocessing
##################

### temporary target
TEMPTARGET=${OUTPUT}"/temptargettx.v3draw"
if ( is_file_exist "$TEMPTARGET" )
then
echo "Temp TARGET exists"
else
#---exe---#
message " Creating a symbolic link to 20x target "
ln -s ${TAR} ${TEMPTARGET}
fi

TAR=$TEMPTARGET

### convert to 8bit v3draw file
SUBBRAW=${OUTPUT}/"subbrain.v3draw"
SUBVRAW=${OUTPUT}/"subvnc.v3draw"

if ( is_file_exist "$SUBBRAW" )
then
echo " SUBBRAW: $SUBBRAW exists"
else
#---exe---#
message " Converting to v3draw file "
$Vaa3D -cmd image-loader -convert8 $SUBBRAIN $SUBBRAW
fi

if ( is_file_exist "$SUBVRAW" )
then
echo " SUBVRAW $SUBVRAW exists"
else
#---exe---#
message " Converting to v3draw file "
$Vaa3D -cmd image-loader -convert8 $SUBVNC $SUBVRAW
fi

### shrinkage ratio
# VECTASHIELD/DPXEthanol = 0.82
# VECTASHIELD/DPXPBS = 0.86
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
 
echo "echo $DPXSHRINKRATIO*$RESTX_X | bc -l"
RESTX_X=`echo $DPXSHRINKRATIO*$RESTX_X | bc -l`
echo "echo $DPXSHRINKRATIO*$RESTX_Y | bc -l"
RESTX_Y=`echo $DPXSHRINKRATIO*$RESTX_Y | bc -l`
echo "echo $DPXSHRINKRATIO*$RESTX_Z | bc -l"
RESTX_Z=`echo $DPXSHRINKRATIO*$RESTX_Z | bc -l`

DPXRI=1.55

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
$Vaa3D -x ireg -f isampler -i $SUBBRAW -o $SUBTXIS -p "#x $SRX #y $SRY #z $SRZ"
fi

# for warping the neurons
SMLMAT=${OUTPUT}"/neubrainSampling.txt"

NWSRX=`echo 1.0/$SRX | bc -l`
NWSRY=`echo 1.0/$SRY | bc -l`
NWSRZ=`echo 1.0/$SRZ | bc -l`

if ( is_file_exist "$SMLMAT" )
then
echo " SMLMAT: $SMLMAT exists"
else
#---exe---#
message " Generating transformation matrix for sampling brain neurons "
echo "#Insight Transform File V1.0" >> $SMLMAT
echo "#Transform 0" >> $SMLMAT
echo "Transform: AffineTransform_double_3_3" >> $SMLMAT
echo "Parameters: $NWSRX 0 0 0 $NWSRY 0 0 0 $NWSRZ 0 0 0" >> $SMLMAT
echo "FixedParameters: 0 0 0" >> $SMLMAT
echo "" >> $SMLMAT
fi

##################
# Alignment
##################

#
### global alignment
#

message " Global alignment "

MAXITERATIONS=10000x10000x10000
GRADDSCNTOPTS=0.5x0.95x1.e-4x1.e-4
DSRATIO=0.5

TARREF=$((TARREF-1));
SUBREF=$((SUBREF-1));

### global align $SUBTXIS to $TARTX

STRT=`echo $TAR | awk -F\. '{print $1}'`
STRS=`echo $SUBTXIS | awk -F\. '{print $1}'`

FIXED=$STRT"_c"$TARREF".nii"
MOVING=$STRS"_c"$SUBREF".nii"

MOVINGFC=$STRS"_c0.nii"
MOVINGSC=$STRS"_c1.nii"

SUBFC=$STRS"_c0_deformed.nii"
SUBSC=$STRS"_c1_deformed.nii"

SUBBRAINDeformed=${OUTPUT}"/AlignedFlyBrain.v3draw"

SIMMETRIC=${OUTPUT}"/txmi"
AFFINEMATRIX=${OUTPUT}"/txmiAffine.txt"

SUBISNIIDS=${OUTPUT}"/subtxIS_c"${SUBREF}"_ds.nii"
TARTXNIIDS=${OUTPUT}"/temptargettx_c0_ds.nii"

if ( is_file_exist "$FIXED" )
then
echo " FIXED: $FIXED exists"
else
#---exe---#
message " Converting 20x target into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $TAR
fi

if ( is_file_exist "$MOVING" )
then
echo " MOVING: $MOVING exists"
else
#---exe---#
message " Converting 20x subject into Nifti image "
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBTXIS
fi

if ( is_file_exist "$TARTXNIIDS" )
then
echo " TARTXNIIDS: $TARTXNIIDS exists"
else
#---exe---#
message " Downsampling 20x target "
$Vaa3D -x ireg -f resamplebyspacing -i $FIXED -o $TARTXNIIDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

if ( is_file_exist "$SUBISNIIDS" )
then
echo " SUBISNIIDS: $SUBISNIIDS exists"
else
#---exe---#
message " Downsampling 20x subject "
$Vaa3D -x ireg -f resamplebyspacing -i $MOVING -o $SUBISNIIDS -p "#x $DSRATIO #y $DSRATIO #z $DSRATIO" 
fi

if ( is_file_exist "$AFFINEMATRIX" )
then
echo " AFFINEMATRIX: $AFFINEMATRIX exists"
else
#---exe---#
message " Global aligning 20x fly brain to 20x target brain "
$ANTS 3 -m MI[ $TARTXNIIDS, $SUBISNIIDS, 1, 32] -o $SIMMETRIC -i 0 --number-of-affine-iterations $MAXITERATIONS --rigid-affine true --affine-gradient-descent-option $GRADDSCNTOPTS
fi


### extract rotation matrix from the affine matrix

ROTMATRIX=${OUTPUT}"/txmiRotation.txt"

if ( is_file_exist "$ROTMATRIX" )
then
echo " ROTMATRIX: $ROTMATRIX exists"
else
#---exe---#
message " Extracting roations from the rigid transformations "
$Vaa3D -x ireg -f extractRotMat -i $AFFINEMATRIX -o $ROTMATRIX
fi

#
### local alignment
#

message " Local alignment "

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
message " Local aligning 20x fly brain to 20x target brain "
$ANTS 3 -m  CC[ $TARTXNIIDS, $SUBISNIIDS, 0.75, 4] -m MI[ $TARTXNIIDS, $SUBISNIIDS, 0.25, 32] -t SyN[0.25]  -r Gauss[3,0] -o $SIMMETRIC -i $MAXITERSCC --initial-affine $AFFINEMATRIX
fi

### warp

# brain

if ( is_file_exist "$SUBSC" )
then
echo " SUBSC: $SUBSC exists"
else
#---exe---#
message " Warping 20x subject "
$WARP 3 $MOVINGFC $SUBFC -R $FIXED $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
$WARP 3 $MOVINGSC $SUBSC -R $FIXED $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if ( is_file_exist "$SUBBRAINDeformed" )
then
echo " SUBBRAINDeformed: $SUBBRAINDeformed exists"
else
#---exe---#
message " Combining the 2 aligned images into one stack "
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBFC $SUBSC -o $SUBBRAINDeformed -p "#b 1 #v 1"
fi

# vnc

SUBVNCRotated=${FINALOUTPUT}"/AlignedFlyVNC.v3draw"

if ( is_file_exist "$SUBVNCRotated" )
then
echo " SUBVNCRotated: $SUBVNCRotated exists"
else
#---exe---#
message " Warping VNC images "
$Vaa3D -x ireg -f iwarp -o $SUBVNCRotated -p "#s $SUBVRAW #t $SUBVRAW #a $ROTMATRIX"
fi

## brain neurons
STRN=`echo $NEUBRAIN | awk -F\. '{print $1}'`
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

NEURONSNII=${STRN}"_yflip_c0.nii"

if ( is_file_exist "$NEURONSNII" )
then
echo "NEURONSNII: $NEURONSNII exists."
else
#---exe---#
message " Converting Neurons into Nifti "
$Vaa3D -x ireg -f NiftiImageConverter -i $NEUBRAINYFLIP
echo ""
fi

NEUBRAINSMPLD=${STRN}"_yflip_c0_sampled.nii"

if ( is_file_exist "$NEUBRAINSMPLD" )
then
echo "NEUBRAINSMPLD: $NEUBRAINSMPLD exists."
else
#---exe---#
message " Sampline neurons with the same ratio "
$WARPMT -d 3 -i $NEURONSNII -r $MOVINGFC -t $SMLMAT -n MultiLabel[0.8x0.8x0.8vox,4.0] -o $NEUBRAINSMPLD
echo ""
fi

NEUBRAINDFMD=${OUTPUT}"/NeuronBrainAligned.nii"
NEUBRAINALIGNED=${OUTPUT}"/NeuronBrainAligned.v3draw"

if ( is_file_exist "$NEUBRAINALIGNED" )
then
echo " NEUBRAINALIGNED: $NEUBRAINALIGNED exists"
else
#---exe---#
message " Warping Neurons "
$WARPMT -d 3 -i $NEUBRAINSMPLD -r $FIXED -n MultiLabel[0.8x0.8x0.8vox,4.0] -t $AFFINEMATRIXLOCAL -t $FWDDISPFIELD -o $NEUBRAINDFMD

$Vaa3D -x ireg -f NiftiImageConverter -i $NEUBRAINDFMD -o $NEUBRAINALIGNED -p "#b 1 #v 2 #r 0"
echo ""
fi

NEUBRAINALIGNEDYFLIP=${OUTPUT}"/NeuronBrainAligned_yflip.v3draw"

if ( is_file_exist "$NEUBRAINALIGNEDYFLIP" )
then
echo " NEUBRAINALIGNEDYFLIP: $NEUBRAINALIGNEDYFLIP exists"
else
#---exe---#
message " Y-Flipping neurons back "
$Vaa3D -x ireg -f yflip -i $NEUBRAINALIGNED -o $NEUBRAINALIGNEDYFLIP
echo ""
fi

## vnc neurons
STRNVNC=`echo $NEUVNC | awk -F\. '{print $1}'`
STRNVNC=`basename $STRNVNC`
STRNVNC=${OUTPUT}/${STRNVNC}
NEUVNCYFLIP=${STRNVNC}"_yflip.v3draw"

if ( is_file_exist "$NEUVNCYFLIP" )
then
echo " NEUVNCYFLIP: $NEUVNCYFLIP exists"
else
#---exe---#
message " Y-Flipping neurons first "
$Vaa3D -x ireg -f yflip -i $NEUVNC -o $NEUVNCYFLIP
echo ""
fi

NEUVNCNII=${STRNVNC}"_yflip_c0.nii"

if ( is_file_exist "$NEUVNCNII" )
then
echo "NEUVNCNII: $NEUVNCNII exists."
else
#---exe---#
message " Converting Neurons into Nifti "
$Vaa3D -x ireg -f NiftiImageConverter -i $NEUVNCYFLIP
echo ""
fi

NEUVNCDFMD=${OUTPUT}"/NeuronVNCAligned.nii"
NEUVNCALIGNED=${OUTPUT}"/NeuronVNCAligned.v3draw"

VNCROTMAT=${OUTPUT}"/vncrotmat.txt"

if ( is_file_exist "$VNCROTMAT" )
then
echo " VNCROTMAT: $VNCROTMAT exists"
else
#---exe---#
message " Generating transformation matrix for warping vnc neurons"

CENTERX=`echo ${DIMX} / 2.0 | bc -l`
CENTERY=`echo ${DIMY} / 2.0 | bc -l`
CENTERZ=`echo ${DIMZ} / 2.0 | bc -l`

while read LINE
do

if [[ $LINE =~ "#Insight Transform File" ]]
then
echo $LINE >> $VNCROTMAT
elif [[ $LINE =~ "#Transform" ]]
then
echo $LINE >> $VNCROTMAT
elif [[ $LINE =~ "Transform:" ]]
then
echo $LINE >> $VNCROTMAT
elif [[ $LINE =~ "Parameters:" ]] && [[ ! $LINE =~ "FixedParameters:" ]]
then
echo $LINE >> $VNCROTMAT
elif [[ $LINE =~ "FixedParameters:" ]]
then
echo "FixedParameters: $CENTERX $CENTERY $CENTERZ" >> $VNCROTMAT
fi

done < $ROTMATRIX
echo "" >> $VNCROTMAT
fi

if ( is_file_exist "$NEUVNCALIGNED" )
then
echo " NEUVNCALIGNED: $NEUVNCALIGNED exists"
else
#---exe---#
message " Warping Neurons "
$WARPMT -d 3 -i $NEUVNCNII -r $NEUVNCNII -n MultiLabel[0.8x0.8x0.8vox,4.0] -t $VNCROTMAT -o $NEUVNCDFMD

$Vaa3D -x ireg -f NiftiImageConverter -i $NEUVNCDFMD -o $NEUVNCALIGNED -p "#b 1 #v 2 #r 0"
echo ""
fi

NEUVNCALIGNEDYFLIP=${FINALOUTPUT}"/ConsolidatedLabelVNC.v3draw"

if ( is_file_exist "$NEUVNCALIGNEDYFLIP" )
then
echo " NEUVNCALIGNEDYFLIP: $NEUVNCALIGNEDYFLIP exists"
else
#---exe---#
message " Y-Flipping neurons back "
$Vaa3D -x ireg -f yflip -i $NEUVNCALIGNED -o $NEUVNCALIGNEDYFLIP
echo ""
fi

##################
# 20x unified
##################

VECTARI=0.6957

SUBALIGNED=${OUTPUT}"/AlignedFlyBrainRIcorrected.v3draw"

if ( is_file_exist "$SUBALIGNED" )
then
echo " SUBALIGNED: $SUBALIGNED exists"
else
#---exe---#
message " Obtain final aligned result "
$Vaa3D -x ireg -f isampler -i $SUBBRAINDeformed -o $SUBALIGNED -p "#x 1.0 #y 1.0 #z $VECTARI"
fi

SUBALIGNEDUNIFIED=${FINALOUTPUT}"/AlignedFlyBrain.v3draw"

if ( is_file_exist "$SUBALIGNEDUNIFIED" )
then
echo " SUBALIGNEDUNIFIED: $SUBALIGNEDUNIFIED exists"
else
#---exe---#
message " Rescale to unified space "
$Vaa3D -x ireg -f prepare20xData -o $SUBALIGNEDUNIFIED -p "#s $SUBALIGNED #t $ATLAS"
fi

# for warping the neurons
RICMAT=${OUTPUT}"/neubrainRIcorrect.txt"

if ( is_file_exist "$RICMAT" )
then
echo " RICMAT: $RICMAT exists"
else
#---exe---#
message " Generating transformation matrix for brain neurons RI correction "
echo "#Insight Transform File V1.0" >> $RICMAT
echo "#Transform 0" >> $RICMAT
echo "Transform: AffineTransform_double_3_3" >> $RICMAT
echo "Parameters: 1.0 0 0 0 1.0 0 0 0 $DPXRI 0 0 0" >> $RICMAT
echo "FixedParameters: 0 0 0" >> $RICMAT
echo "" >> $RICMAT
fi

NEUBRAINNII=${OUTPUT}"/NeuronBrainAligned_yflip_c0.nii"
BRAINNII=${OUTPUT}"/AlignedFlyBrainRIcorrected_c0.nii"

if ( is_file_exist "$NEUBRAINNII" )
then
echo "NEURONSNII: $NEUBRAINNII exists."
else
#---exe---#
message " Converting Neurons into Nifti "
$Vaa3D -x ireg -f NiftiImageConverter -i $NEUBRAINALIGNEDYFLIP
$Vaa3D -x ireg -f NiftiImageConverter -i $SUBALIGNED
echo ""
fi

NEUBRAINRIC=${OUTPUT}"/NeuronBrainAligned_yflip_ric.nii"
NEUBRAINRICRAW=${OUTPUT}"/NeuronBrainAligned_yflip_ric.v3draw"

if ( is_file_exist "$NEUBRAINRIC" )
then
echo "NEUBRAINSMPLD: $NEUBRAINRIC exists."
else
#---exe---#
message " Sampline neurons with the same ratio "
$WARPMT -d 3 -i $NEUBRAINNII -r $BRAINNII -t $RICMAT -n MultiLabel[0.8x0.8x0.8vox,4.0] -o $NEUBRAINRIC
$Vaa3D -x ireg -f NiftiImageConverter -i $NEUBRAINRIC -o $NEUBRAINRICRAW -p "#b 1 #v 2 #r 0"
echo ""
fi

BRAINNEUUNIFIED=${FINALOUTPUT}"/ConsolidatedLabelBrain.v3draw"

if ( is_file_exist "$BRAINNEUUNIFIED" )
then
echo " BRAINNEUUNIFIED: $BRAINNEUUNIFIED exists"
else
#---exe---#
message " Rescale aligned Neuron to the unified space "
$Vaa3D -x ireg -f prepare20xData -o $BRAINNEUUNIFIED -p "#s $NEUBRAINRICRAW #t $ATLAS #k 1"
fi


##################
# evalutation
##################

AQ=${OUTPUT}"/AlignmentQuality.txt"

SUBREF=$((SUBREF+1))
#TARREF=$((TARREF+1))

if ( is_file_exist "$AQ" )
then
echo " AQ exists"
else
#---exe---#
message " Evaluating "
#$Vaa3D -x ireg -f evalAlignQuality -o $AQ -p "#s $SUBALIGNEDUNIFIED #cs $SUBREF #t $ATLAS"
$Vaa3D -x ireg -f esimilarity -o $AQ -p "#s $SUBALIGNEDUNIFIED #cs $SUBREF #t $ATLAS"
fi

while read LINE
do
read SCORE
done < $AQ;

message " Generating Verification Movie "
ALIGNVERIFY=AlignVerify.mp4
$DIR/createVerificationMovie.sh -c $CONFIGFILE -k $TOOLDIR -w $WORKDIR -s $SUBALIGNEDUNIFIED -i $ATLAS -r $SUBREF -o ${FINALOUTPUT}/$ALIGNVERIFY

##################
# Output Meta
##################

if [[ -f "$SUBALIGNEDUNIFIED" ]]; then
META=${FINALOUTPUT}"/AlignedFlyBrain.properties"
echo "alignment.stack.filename=AlignedFlyBrain.v3draw" >> $META
echo "alignment.image.channels=$INPUT1_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT1_REF" >> $META
echo "alignment.space.name=$UNIFIED_SPACE" >> $META
echo "alignment.resolution.voxels=0.62x0.62x0.62" >> $META
echo "alignment.image.size=1024x512x218" >> $META
echo "alignment.objective=20x" >> $META
echo "default=true" >> $META
if [[ -f "$BRAINNEUUNIFIED" ]]; then
echo "neuron.masks.filename=ConsolidatedLabelBrain.v3draw" >> $META
fi
echo "alignment.quality.score.ncc=$SCORE" >> $META
fi

if [[ -f "$SUBVNCRotated" ]]; then
META=${FINALOUTPUT}"/AlignedFlyVNC.properties"
echo "alignment.stack.filename=AlignedFlyVNC.v3draw" >> $META
echo "alignment.image.channels=$INPUT2_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT2_REF" >> $META
echo "alignment.space.name=VNC Space" >> $META
echo "alignment.resolution.voxels=${VNCRES}" >> $META
echo "alignment.image.size=${VNCDIMS}" >> $META
echo "alignment.objective=20x" >> $META
fi

