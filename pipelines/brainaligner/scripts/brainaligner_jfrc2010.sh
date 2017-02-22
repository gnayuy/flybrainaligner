#!/bin/bash
#
# The alignment pipeline for fly brains, version 1.0, Feburary 21, 2017
# developed by Yang Yu (yuy@janleia.hhmi.org)
#

################################################################################
#
# Subject: fly brains
# Target: 20x JFRC2010
# Voxel Size: (20x) (0.62x0.62x0.62 um)
#
################################################################################

start=`date +%s.%N`

##################
#
### Basic Funcs
#
##################

DIR=$(cd "$(dirname "$0")"; pwd)
. $DIR/common.sh

##################
#
### Inputs
#
##################

parseParameters "$@"

CONFIGFILE=$CONFIG_FILE
TMPLDIR=$TEMPLATE_DIR
TOOLDIR=$TOOL_DIR
WORKDIR=$WORK_DIR

MP=$MOUNTING_PROTOCOL
NEUBRAIN=$INPUT1_NEURONS

# subject parameters
SUB=$INPUT1_FILE
SUBREF=$INPUT1_REF
SUBNEURONS=$INPUT1_NEURONS
RESTX=$INPUT1_RESX
RESTY=$INPUT1_RESY
RESTZ=$INPUT1_RESZ
CHN=$INPUT1_CHANNELS

# special parameters
ZFLIP=$ZFLIP
GENDER=$GENDER

# tools
Vaa3D=`readItemFromConf $CONFIGFILE "Vaa3D"`
JBA=`readItemFromConf $CONFIGFILE "JBA"`
ANTS=`readItemFromConf $CONFIGFILE "ANTS"`
WARP=`readItemFromConf $CONFIGFILE "WARP"`
FLIRT=`readItemFromConf $CONFIGFILE "FSLFLIRT"`

Vaa3D=${TOOLDIR}"/"${Vaa3D}
JBA=${TOOLDIR}"/"${JBA}
ANTS=${TOOLDIR}"/"${ANTS}
WARP=${TOOLDIR}"/"${WARP}
FLIRT=${TOOLDIR}"/"${FLIRT}

# templates
TARTX=`readItemFromConf $CONFIGFILE "atlasFBTX"`
TARTXEXT=`readItemFromConf $CONFIGFILE "tgtFBRCTX"`
TARREF=`readItemFromConf $CONFIGFILE "REFNO"`
RESTX_X=`readItemFromConf $CONFIGFILE "VSZX_20X_IS"`
RESTX_Y=`readItemFromConf $CONFIGFILE "VSZY_20X_IS"`
RESTX_Z=`readItemFromConf $CONFIGFILE "VSZZ_20X_IS"`

INITAFFINE=`readItemFromConf $CONFIGFILE "IDENTITYMATRIX"`

TARTX=${TMPLDIR}"/"${TARTX}
TARTXEXT=${TMPLDIR}"/"${TARTXEXT}
INITAFFINE=${TMPLDIR}"/"${INITAFFINE}

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "TMPLDIR: $TMPLDIR"
echo "TOOLDIR: $TOOLDIR"
echo "WORKDIR: $WORKDIR"

echo "MountingProtocol: $MP"

echo "SUB: $SUB"
echo "SUBREF: $SUBREF"
echo "SUBNEURONS: $SUBNEURONS"
echo "RESTX: $RESTX"
echo "RESTY: $RESTY"
echo "RESTZ: $RESTZ"
echo "CHN: $CHN"

message "Vars..."
echo "Vaa3D: $Vaa3D"
echo "ANTS: $ANTS"
echo "WARP: $WARP"
echo "FLIRT: $FLIRT"

echo "TARREF: $TARREF"
echo "TARTX: $TARTX"
echo "TARTXEXT: $TARTXEXT"

echo "RESTX_X: $RESTX_X"
echo "RESTX_Y: $RESTX_Y"
echo "RESTX_Z: $RESTX_Z"

echo "INITAFFINE: $INITAFFINE"

echo ""

# convert inputs to raw format
ensureRawFile "$Vaa3D" "$WORKDIR" "$SUB" SUB
echo "RAW SUB : $SUB"
ensureRawFileWdiffName "$Vaa3D" "$WORKDIR" "$SUBNEURONS" "${SUBNEURONS%.*}_INPUT.v3draw" SUBNEURONS
echo "RAW SUBNEURONS: $SUBNEURONS"

# Outputs/
#         temporary files will be deleted
#
# FinalOutputs/
#               Brains/
#               Neurons/
#               Transformations/
#
OUTPUT=${WORKDIR}"/Outputs"
FINALOUTPUT=${WORKDIR}"/FinalOutputs"

if [ ! -d $OUTPUT ]; then 
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then 
mkdir $FINALOUTPUT
fi

OUTBRAINS=${WORKDIR}"/FinalOutputs/Brains"
if [ ! -d $OUTBRAINS ]; then
mkdir $OUTBRAINS
fi

OUTNEURONS=${WORKDIR}"/FinalOutputs/Neurons"
if [ ! -d $OUTNEURONS ]; then
mkdir $OUTNEURONS
fi

OUTTRANSFORMATIONS=${WORKDIR}"/FinalOutputs/Transformations"
if [ ! -d $OUTTRANSFORMATIONS ]; then
mkdir $OUTTRANSFORMATIONS
fi

#############

TARTXEXTDX=1280
TARTXEXTDY=1024
TARTXEXTDZ=368

#############

#############
#
### preprocessing
#
#############

### temporary target
TEMPTARGET=${OUTPUT}"/temptarget.tif"
if ( is_file_exist "$TEMPTARGET" )
then
echo "TEMPTARGET: $TEMPTARGET exists"
else
#---exe---#
message " Creating a symbolic link to 20x target "
ln -s ${TARTX} ${TEMPTARGET}
fi
TARTX=$TEMPTARGET

TEMPTARGET=${OUTPUT}"/temptargetext.v3draw"
if ( is_file_exist "$TEMPTARGET" )
then
echo "TEMPTARGET: $TEMPTARGET exists"
else
#---exe---#
message " Creating a symbolic link to 20x target "
ln -s ${TARTXEXT} ${TEMPTARGET}
fi
TARTXEXT=$TEMPTARGET

### temporary subject
TEMPSUBJECT=${OUTPUT}"/tempsubject.v3draw"
if ( is_file_exist "$TEMPSUBJECT" )
then
echo "TEMPSUBJECT: $TEMPSUBJECT exists"
else

if [[ $ZFLIP =~ "zflip" ]]
then
#---exe---#
message " Flipping 20x subject along z-axis "
time $Vaa3D -x ireg -f zflip -i ${SUB} -o ${TEMPSUBJECT}
else
#---exe---#
message " Creating a symbolic link to 20x subject "
ln -s ${SUB} ${TEMPSUBJECT}
fi

fi
SUB=$TEMPSUBJECT

#############

# FIXED
TARTXNII=${OUTPUT}"/temptargetext_c0.nii"
if ( is_file_exist "$TARTXNII" )
then
echo " TARTXNII: $TARTXNII exists"
else
#---exe---#
message " Converting the target into Nifti image "
time $Vaa3D -x ireg -f NiftiImageConverter -i $TARTXEXT
fi

# MOVING

# sampling the subject if the voxel size is not the same to the target

ISRX=`echo $RESTX/$RESTX_X | bc -l`
ISRY=`echo $RESTY/$RESTX_Y | bc -l`
ISRZ=`echo $RESTZ/$RESTX_Z | bc -l`

SRXC=$(bc <<< "$ISRX - 1.0")
SRYC=$(bc <<< "$ISRY - 1.0")
SRZC=$(bc <<< "$ISRZ - 1.0")

ASRXC=`echo $SRXC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
ASRYC=`echo $SRYC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
ASRZC=`echo $SRZC | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`

SUBIS=${OUTPUT}"/SUBIS.v3draw"
if [ $(bc <<< "$ASRXC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRYC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRZC < 0.01") -eq 1 ]; then

message " The resolution of the subject is the same to the target "
ln -s $SUB $SUBIS

else

message "sampling with ratio $ISRX $ISRY $ISRZ"
if ( is_file_exist "$SUBIS" )
then
echo " SUBIS: $SUBIS exists"
else
#---exe---#
message " Isotropic sampling 20x subject "
time $Vaa3D -x ireg -f isampler -i $SUB -o $SUBIS -p "#x $ISRX #y $ISRY #z $ISRZ"
fi

fi

SUBRS=${OUTPUT}"/SUBRs.v3draw"
if ( is_file_exist "$SUBRS" )
then
echo " SUBRS: $SUBRS exists"
else
#---exe---#
message " Resizing the 20x subject to 20x target "
time $Vaa3D -x ireg -f resizeImage -o $SUBRS -p "#s $SUBIS #t $TARTXEXT #y 1"
fi

SUBRSRFC=${OUTPUT}"/SUBRsRefChn.v3draw"
if ( is_file_exist "$SUBRSRFC" )
then
echo " SUBRSRFC: $SUBRSRFC exists"
else
#---exe---#
message " Extracting the reference of the 20x subject "
time $Vaa3D -x refExtract -f refExtract -i $SUBRS -o $SUBRSRFC -p "#c $SUBREF";
fi

#############
#
### global alignment
#
#############

message " Global alignment : affine transformations"

### 1) estimate rotations

SUBRSRFCNII=${OUTPUT}"/SUBRsRefChn_c0.nii"
if ( is_file_exist "$SUBRSRFCNII" )
then
echo " SUBRSRFCNII: $SUBRSRFCNII exists"
else
#---exe---#
message " Converting the subject reference channel into a Nifti image "
time $Vaa3D -x ireg -f NiftiImageConverter -i $SUBRSRFC
fi

DSFAC=0.25
FDS=${OUTPUT}"/tar_ds.nii"
MDS=${OUTPUT}"/sub_ds.nii"

if ( is_file_exist "$FDS" )
then
echo " FDS: $FDS exists"
else
#---exe---#
message " Downsampling the target with ratio 1/8"
time $Vaa3D -x ireg -f resamplebyspacing -i $TARTXNII -o $FDS -p "#x $DSFAC #y $DSFAC #z $DSFAC"
fi

if ( is_file_exist "$MDS" )
then
echo " MDS: $MDS exists"
else
#---exe---#
message " Downsampling the subject with ratio 1/8"
time $Vaa3D -x ireg -f resamplebyspacing -i $SUBRSRFCNII -o $MDS -p "#x $DSFAC #y $DSFAC #z $DSFAC"
fi

RCMAT=${OUTPUT}"/rotations.mat"
RCOUT=${OUTPUT}"/rotations.txt"
RCAFFINE=${OUTPUT}"/rotationsAffine.txt"

if ( is_file_exist "$RCMAT" )
then
echo " RCMAT: $RCMAT exists"
else
#---exe---#
message " Find the rotations with FSL/flirt "
time $FLIRT -in $MDS -ref $FDS -omat $RCMAT -cost mutualinfo -searchrx -120 120 -searchry -120 120 -searchrz -120 120 -dof 12 -datatype char
fi

if ( is_file_exist "$RCOUT" )
then
echo " RCOUT: $RCOUT exists"
else
#---exe---#
message " convert Affine matrix .mat to Insight Transform File .txt " 
cnt=1
while IFS=' ' read -ra str;
do

if(( cnt == 1))
then

r11=${str[0]}
r21=${str[1]}
r31=${str[2]}

elif ((cnt == 2))
then

r12=${str[0]}
r22=${str[1]}
r32=${str[2]}

elif ((cnt == 3))
then

r13=${str[0]}
r23=${str[1]}
r33=${str[2]}

fi

cnt=$((cnt+1))

done < $RCMAT

message "Parameters: $r11 $r12 $r13 $r21 $r22 $r23 $r31 $r32 $r33"

echo "#Insight Transform File V1.0" > $RCOUT
echo "#Transform 0" >> $RCOUT
echo "Transform: MatrixOffsetTransformBase_double_3_3" >> $RCOUT
echo "Parameters: $r11 $r12 $r13 $r21 $r22 $r23 $r31 $r32 $r33 0 0 0" >> $RCOUT
echo "FixedParameters: 0 0 0" >> $RCOUT

fi

if ( is_file_exist "$RCAFFINE" )
then
echo " RCAFFINE: $RCAFFINE exists"
else
#---exe---#
message " Estimate rotations "
time $Vaa3D -x ireg -f extractRotMat -i $RCOUT -o $RCAFFINE
fi


### 2) global alignment with ANTs

MAXITERATIONS=10000x10000x10000x10000

SUBRFCROT=${OUTPUT}"/SUBRefChnRsRot.v3draw"
if ( is_file_exist "$SUBRFCROT" )
then
echo " SUBRFCROT: $SUBRFCROT exists"
else
#---exe---#
message " Rotate the subject "
time $Vaa3D -x ireg -f iwarp -o $SUBRFCROT -p "#s $SUBRSRFC #t $TARTXEXT #a $RCAFFINE"
fi

# MOVING
SUBNII=${OUTPUT}"/SUBRefChnRsRot_c0.nii"
if ( is_file_exist "$SUBNII" )
then
echo " SUBNII: $SUBNII exists"
else
#---exe---#
message " Converting the subject into a Nifti image "
time $Vaa3D -x ireg -f NiftiImageConverter -i $SUBRFCROT
fi

SIMMETRIC=${OUTPUT}"/txmi"
AFFINEMATRIX=${OUTPUT}"/txmiAffine.txt"

if ( is_file_exist "$AFFINEMATRIX" )
then
echo " AFFINEMATRIX: $AFFINEMATRIX exists"
else
#---exe---#
message " Global aligning the subject to the target with ANTs"
time $ANTS 3 -m  MI[ $TARTXNII, $SUBNII, 1, 32] -o $SIMMETRIC -i 0 --number-of-affine-iterations $MAXITERATIONS #--rigid-affine true
fi

#############
#
### local alignment
#
#############

message "Local alignment : to find nonlinear transformations"

# warp the subject with linear transformations: $RCAFFINE and $AFFINEMATRIX

SUBRSROT=${OUTPUT}"/SUBRsRotated.v3draw"
if ( is_file_exist "$SUBRSROT" )
then
echo " SUBRSROT: $SUBRSROT exists"
else
#---exe---#
message " Rotated the recentered subject "
time $Vaa3D -x ireg -f iwarp2 -o $SUBRSROT -p "#s $SUBRS #a $RCAFFINE #dx $TARTXEXTDX #dy $TARTXEXTDY #dz $TARTXEXTDZ"
fi

SUBRSROTGA=${OUTPUT}"/subjectGlobalAligned.v3draw"
if ( is_file_exist "$SUBRSROTGA" )
then
echo " SUBRSROTGA: $SUBRSROTGA exists"
else
#---exe---#
message " Affine transforming rotated the subject "
time $Vaa3D -x ireg -f iwarp2 -o $SUBRSROTGA -p "#s $SUBRSROT #a $AFFINEMATRIX #dx $TARTXEXTDX #dy $TARTXEXTDY #dz $TARTXEXTDZ"
fi

### extract VOIs and then align VOIs

# MOVING
SUBRSROTGARS=${OUTPUT}"/subjectGlobalAligned_rs.v3draw"
TARTXRS=${OUTPUT}"/temptarget_rs.v3draw"
if ( is_file_exist "$SUBRSROTGARS" )
then
echo " SUBRSROTGARS: $SUBRSROTGARS exists"
else
#---exe---#
message " Resizing the subject to the original target "
time $Vaa3D -x ireg -f genVOIs -p "#s $SUBRSROTGA #t $TARTX"
fi

#
if(($CHN>0))
then
MOVINGNIICI=${OUTPUT}"/subjectGlobalAligned_rs_c0.nii"
fi

if(($CHN>1))
then
MOVINGNIICII=${OUTPUT}"/subjectGlobalAligned_rs_c1.nii"
fi

if(($CHN>2))
then
MOVINGNIICIII=${OUTPUT}"/subjectGlobalAligned_rs_c2.nii"
fi

if(($CHN>3))
then
MOVINGNIICIV=${OUTPUT}"/subjectGlobalAligned_rs_c3.nii"
fi

SUBREF_ZEROIDX=$((SUBREF-1));
MOVINGNIICR=${OUTPUT}"/subjectGlobalAligned_rs_c"${SUBREF_ZEROIDX}".nii"
if ( is_file_exist "$MOVINGNIICR" )
then
echo " MOVINGNIICR: $MOVINGNIICR exists"
else
#---exe---#
message " Converting 20x subject VOI into Nifti image "
time $Vaa3D -x ireg -f NiftiImageConverter -i $SUBRSROTGARS
fi

# FIXED
FIXEDNII=${OUTPUT}"/temptarget_rs_c0.nii"
if ( is_file_exist "$FIXEDNII" )
then
echo " FIXEDNII: $FIXEDNII exists"
else
#---exe---#
message " Converting the target into Nifti image "
time $Vaa3D -x ireg -f NiftiImageConverter -i $TARTXRS
fi

# local alignment

FIX=$FIXEDNII
MOV=$MOVINGNIICR

SIMMETRIC=${OUTPUT}"/ccmi"
AFFINEMATRIXLOCAL=${OUTPUT}"/ccmiAffine.txt"
FWDDISPFIELD=${OUTPUT}"/ccmiWarp.nii.gz"
BWDDISPFIELD=${OUTPUT}"/ccmiInverseWarp.nii.gz"

MAXITERSCC=100x70x50x0x0

if ( is_file_exist "$AFFINEMATRIXLOCAL" )
then
echo " AFFINEMATRIXLOCAL: $AFFINEMATRIXLOCAL exists"
else
#---exe---#
message " Local alignment "
time $ANTS 3 -m  CC[ $FIX, $MOV, 1, 8] -t SyN[0.25]  -r Gauss[3,0] -o $SIMMETRIC -i $MAXITERSCC
fi

#############
#
### warping
#
#############

#
### warp brains
#

MOVINGDFRMDCR=${OUTPUT}"/subjectGlobalAlignedRs_c"${SUBREF_ZEROIDX}"_deformed.nii"

SUBDFRMD=${OUTPUT}"/Aligned20xScaleRs.v3draw"
SUBALINGED=${OUTBRAINS}"/Aligned20xScale.v3draw"

if ( is_file_exist "$MOVINGDFRMDCR" )
then
echo " MOVINGDFRMDCR: $MOVINGDFRMDCR exists"
else
#---exe---#
message " Warping 20x subject "

if(($CHN>0))
then
MOVINGDFRMDCI=${OUTPUT}"/subjectGlobalAlignedRs_c0_deformed.nii"
time $WARP 3 $MOVINGNIICI $MOVINGDFRMDCI -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>1))
then
MOVINGDFRMDCII=${OUTPUT}"/subjectGlobalAlignedRs_c1_deformed.nii"
time $WARP 3 $MOVINGNIICII $MOVINGDFRMDCII -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>2))
then
MOVINGDFRMDCIII=${OUTPUT}"/subjectGlobalAlignedRs_c2_deformed.nii"
time $WARP 3 $MOVINGNIICIII $MOVINGDFRMDCIII -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

if(($CHN>3))
then
MOVINGDFRMDCIV=${OUTPUT}"/subjectGlobalAlignedRs_c3_deformed.nii"
time $WARP 3 $MOVINGNIICIV $MOVINGDFRMDCIV -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-BSpline
fi

fi

if ( is_file_exist "$SUBDFRMD" )
then
echo " SUBDFRMD: $SUBDFRMD exists"
else
#---exe---#
message " Combining the aligned 20x image channels into one stack "

if(($CHN==1))
then
time $Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI -o $SUBDFRMD -p "#b 1 #v 1"
fi

if(($CHN==2))
then
time $Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI $MOVINGDFRMDCII -o $SUBDFRMD -p "#b 1 #v 1"
fi

if(($CHN==3))
then
time $Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI $MOVINGDFRMDCII $MOVINGDFRMDCIII -o $SUBDFRMD -p "#b 1 #v 1"
fi

if(($CHN==4))
then
time $Vaa3D -x ireg -f NiftiImageConverter -i $MOVINGDFRMDCI $MOVINGDFRMDCII $MOVINGDFRMDCIII $MOVINGDFRMDCIV -o $SUBDFRMD -p "#b 1 #v 1"
fi

fi

if ( is_file_exist "$SUBALINGED" )
then
echo " SUBALINGED: $SUBALINGED exists"
else
#---exe---#
message " Resize the brain to the tamplate's space"
time $Vaa3D -x ireg -f resizeImage -o $SUBALINGED -p "#s $SUBDFRMD #t $TARTX #y 1"
fi

#
### warp neurons
#

if ( is_file_exist "$SUBNEURONS" )
then

STRN=${OUTPUT}"/SUBNeuSegs"
NEURONSYFLIP=${STRN}"_yflip.v3draw"
if ( is_file_exist "$NEURONSYFLIP" )
then
echo " NEURONSYFLIP: $NEURONSYFLIP exists"
else
#---exe---#
message " Y-Flipping the neurons first "
time $Vaa3D -x ireg -f yflip -i $SUBNEURONS -o $NEURONSYFLIP

if [[ $ZFLIP =~ "zflip" ]]
then
#---exe---#
message " Flipping the neurons along z-axis "
time $Vaa3D -x ireg -f zflip -i ${NEURONSYFLIP} -o ${NEURONSYFLIP}
fi

fi

NEURONSYFLIPIS=${STRN}"_yflipIs.v3draw"
if [ $(bc <<< "$ASRXC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRYC < 0.01") -eq 1 ] && [ $(bc <<< "$ASRZC < 0.01") -eq 1 ]; then

message " The resolution of the the neurons is the same to the target "
ln -s $NEURONSYFLIPIS $NEURONSYFLIP

else

if ( is_file_exist "$NEURONSYFLIPIS" )
then
echo " NEURONSYFLIPIS: $NEURONSYFLIPIS exists"
else
#---exe---#
message " Isotropic sampling the neurons "
time $Vaa3D -x ireg -f isampler -i $NEURONSYFLIP -o $NEURONSYFLIPIS -p "#x $ISRX #y $ISRY #z $ISRZ #i 1"
fi

fi

NEURONSYFLIPISRS=${STRN}"_yflipIsRs.v3draw"
if ( is_file_exist "$NEURONSYFLIPISRS" )
then
echo " NEURONSYFLIPISRS: $NEURONSYFLIPISRS exists"
else
#---exe---#
message " Resizing the the neurons to the target "
time $Vaa3D -x ireg -f resizeImage -o $NEURONSYFLIPISRS -p "#s $NEURONSYFLIPIS #t $TARTXEXT #k 1 #i 1 #y 1"
fi

NEURONSYFLIPISRSRT=${STRN}"_yflipIsRsRot.v3draw"
if ( is_file_exist "$NEURONSYFLIPISRSRT" )
then
echo " NEURONSYFLIPISRSRT: $NEURONSYFLIPISRSRT exists"
else
#---exe---#
message " Rotating the neurons "
time $Vaa3D -x ireg -f iwarp2 -o $NEURONSYFLIPISRSRT -p "#s $NEURONSYFLIPISRS #a $RCAFFINE #dx $TARTXEXTDX #dy $TARTXEXTDY #dz $TARTXEXTDZ #i 1"
fi

NEURONSYFLIPISRSRTAFF=${STRN}"_yflipIsRsRotAff.v3draw"
if ( is_file_exist "$NEURONSYFLIPISRSRTAFF" )
then
echo " NEURONSYFLIPISRSRTAFF: $NEURONSYFLIPISRSRTAFF exists"
else
#---exe---#
message " Transforming the neurons "
time $Vaa3D -x ireg -f iwarp2 -o $NEURONSYFLIPISRSRTAFF -p "#s $NEURONSYFLIPISRSRT #a $AFFINEMATRIX #dx $TARTXEXTDX #dy $TARTXEXTDY #dz $TARTXEXTDZ #i 1"
fi

NEURONSYFLIPISRSRTAFFRS=${STRN}"_yflipIsRsRotAffRs.v3draw"
if ( is_file_exist "$NEURONSYFLIPISRSRTAFFRS" )
then
echo " NEURONSYFLIPISRSRTAFFRS: $NEURONSYFLIPISRSRTAFFRS exists"
else
#---exe---#
message " Resize the neurons "
time $Vaa3D -x ireg -f resizeImage -o $NEURONSYFLIPISRSRTAFFRS -p "#s $NEURONSYFLIPISRSRTAFF #t $TARTXRS #y 1"
fi

NEURONSNII=${STRN}"_yflipIsRsRotAffRs_c0.nii"

NEURONDFMD=${STRN}"NeuronAligned20xScale.nii"
NEURONALIGNEDYFLIP=${OUTPUT}"/NeuronAligned20xScale_yflip.v3draw"
NEURONALIGNED=${OUTNEURONS}"/NeuronAligned20xScale.v3draw"
NEURONALIGNEDRS=${OUTPUT}"/NeuronAligned20xScaleRS.v3draw"

if ( is_file_exist "$NEURONSNII" )
then
echo "NEURONSNII: $NEURONSNII exists."
else
#---exe---#
message " Converting 20x neurons into Nifti "
time $Vaa3D -x ireg -f NiftiImageConverter -i $NEURONSYFLIPISRSRTAFFRS
echo ""
fi

if ( is_file_exist "$NEURONALIGNEDYFLIP" )
then
echo " NEURONALIGNEDYFLIP: $NEURONALIGNEDYFLIP exists"
else
#---exe---#
message " Warping 20x neurons "
$WARP 3 $NEURONSNII $NEURONDFMD -R $FIXEDNII $FWDDISPFIELD $AFFINEMATRIXLOCAL --use-NN

time $Vaa3D -x ireg -f NiftiImageConverter -i $NEURONDFMD -o $NEURONALIGNEDYFLIP -p "#b 1 #v 2 #r 0"
fi

if ( is_file_exist "$NEURONALIGNEDRS" )
then
echo " NEURONALIGNEDRS: $NEURONALIGNEDRS exists"
else
#---exe---#
message " Resize the neurons to the tamplate's space"
time $Vaa3D -x ireg -f resizeImage -o $NEURONALIGNEDRS -p "#s $NEURONALIGNEDYFLIP #t $TARTX #y 1"
fi

if ( is_file_exist "$NEURONALIGNED" )
then
echo " NEURONALIGNED: $NEURONALIGNED exists"
else
#---exe---#
message " Y-Flipping 20x neurons back "
time $Vaa3D -x ireg -f yflip -i $NEURONALIGNEDRS -o $NEURONALIGNED
fi

else
echo " SUBNEURONS: $SUBNEURONS does not exist"
fi

### keep all the transformations

RCAFFINESAVE=${OUTTRANSFORMATIONS}"/rotationsAffine.txt"
AFFINEMATRIXSAVE=${OUTTRANSFORMATIONS}"/txmiAffine.txt"
FWDDISPFIELDSAVE=${OUTTRANSFORMATIONS}"/ccmiWarp.nii.gz"
BWDDISPFIELDSAVE=${OUTTRANSFORMATIONS}"/ccmiInverseWarp.nii.gz"
AFFINEMATRIXLOCALSAVE=${OUTTRANSFORMATIONS}"/ccmiAffine.txt"

cp $RCAFFINE $RCAFFINESAVE
cp $AFFINEMATRIX $AFFINEMATRIXSAVE
cp $FWDDISPFIELD $FWDDISPFIELDSAVE
cp $BWDDISPFIELD $BWDDISPFIELDSAVE
cp $AFFINEMATRIXLOCAL $AFFINEMATRIXLOCALSAVE


#############
#
### Evaluations
#
#############


AQ=${OUTPUT}"/AlignmentQuality.txt"

if ( is_file_exist "$AQ" )
then
echo " AQ exists"
else
#---exe---#
message " Evaluating "
time $Vaa3D -x ireg -f esimilarity -o $AQ -p "#s $SUBALINGED #cs $SUBREF #t $TARTX"
fi

while read LINE
do
read SCORE
done < $AQ;


message " Generating Verification Movie "
ALIGNVERIFY=VerifyMovie.mp4
$DIR/createVerificationMovie.sh -c $CONFIGFILE -k $TOOLDIR -w $WORKDIR -s $SUBALINGED -i $TARTX -r $SUBREF -o ${FINALOUTPUT}/$ALIGNVERIFY

#############
#
### Output Meta
#
#############

### Brains

if [[ -f "$SUBALINGED" ]]; then
META=${OUTBRAINS}"/Aligned20xScale.properties"
echo "alignment.stack.filename=Aligned20xScale.v3draw" >> $META
echo "alignment.image.channels=$INPUT1_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT1_REF" >> $META
echo "alignment.verify.filename=${ALIGNVERIFY}" >> $META
echo "alignment.space.name=Arnim 20x Alignment Space" >> $META
echo "alignment.resolution.voxels=${RESTX_X}x${RESTX_Y}x${RESTX_Z}" >> $META
echo "alignment.image.size=1024x512x218" >> $META
echo "alignment.bounding.box=" >> $META
echo "alignment.objective=20x" >> $META
echo "alignment.quality.score.ncc=$SCORE" >> $META
if [[ -f "$NEUALINGED" ]]; then
    echo "neuron.masks.filename=NeuronAligned20xScale.v3draw" >> $META
fi
echo "default=true" >> $META
fi

# execution time
end=`date +%s.%N`
runtime=$( echo "$end - $start" | bc -l )
echo "brainaligner runs $runtime seconds"


