#!/bin/bash
#
# 20x fly brain alignment pipeline using JBA, version 1.0, June 6, 2013
#

################################################################################
#
# The pipeline is developed for aligning 20x fly brain with JBA.
# The standard brain's resolution (0.62x0.62x0.62 um)
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
SUBREF=$INPUT1_REF
CHN=$INPUT1_CHANNELS

NEURONS=$INPUT1_NEURONS

MP=$MOUNTING_PROTOCOL

RESX=$INPUT1_RESX
RESY=$INPUT1_RESY
RESZ=$INPUT1_RESZ

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
ATLAS=`readItemFromConf $CONFIGFILE "atlasFBTX"`
TAR=`readItemFromConf $CONFIGFILE "tgtFBTX"`
TARMARKER=`readItemFromConf $CONFIGFILE "tgtFBTXmarkers"`
TARREF=`readItemFromConf $CONFIGFILE "REFNO"`
RESTX_X=`readItemFromConf $CONFIGFILE "VSZX_20X_IS"`
RESTX_Y=`readItemFromConf $CONFIGFILE "VSZY_20X_IS"`
RESTX_Z=`readItemFromConf $CONFIGFILE "VSZZ_20X_IS"`
LCRMASK=`readItemFromConf $CONFIGFILE "LCRMASK"`
CMPBND=`readItemFromConf $CONFIGFILE "CMPBND"`

TAR=${TMPLDIR}"/"${TAR}
ATLAS=${TMPLDIR}"/"${ATLAS}
TARMARKER=${TMPLDIR}"/"${TARMARKER}
LCRMASK=${TMPLDIR}"/"${LCRMASK}
CMPBND=${TMPLDIR}"/"${CMPBND}

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "TMPLDIR: $TMPLDIR"
echo "TOOLDIR: $TOOLDIR"
echo "WORKDIR: $WORKDIR"
echo "SUBBRAIN: $SUBBRAIN"
echo "SUBREF: $SUBREF"
echo "NEURONS: $NEURONS"
echo "MountingProtocol: $MP"
echo "RESX: $RESX"
echo "RESY: $RESY"
echo "RESZ: $RESZ"
message "Vars..."
echo "Vaa3D: $Vaa3D"
echo "ANTS: $ANTS"
echo "WARP: $WARP"
echo "TAR: $TAR"
echo "TARMARKER: $TARMARKER"
echo "TARREF: $TARREF"
echo "ATLAS: $ATLAS"
echo "LCRMASK: $LCRMASK"
echo "CMPBND: $CMPBND"
echo ""

OUTPUT=${WORKDIR}"/Outputs"
FINALOUTPUT=${WORKDIR}"/FinalOutputs"

if [ ! -d $OUTPUT ]; then 
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then 
mkdir $FINALOUTPUT
fi

ensureRawFile "$Vaa3D" "$OUTPUT" "$NEURONS" NEURONS
echo "RAW NEURONS: $NEURONS"

##################
# Preprocessing
##################

### temporary target
TEMPTARGET=${OUTPUT}"/temptargettx.tif"
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

if ( is_file_exist "$SUBBRAW" )
then
echo " SUBBRAW: $SUBBRAW exists"
else
#---exe---#
message " Converting to v3draw file "
$Vaa3D -cmd image-loader -convert8 $SUBBRAIN $SUBBRAW
fi

STRN=`echo $NEURONS | awk -F\. '{print $1}'`
STRN=`basename $STRN`
STRN=${OUTPUT}/${STRN}
NEURONSYFLIP=${STRN}"_yflip.v3draw"
NEURONSYFLIPOCT=${STRN}"_yflip_8bit.v3draw"

if ( is_file_exist "$NEURONSYFLIPOCT" )
then
echo " NEURONSYFLIPOCT: $NEURONSYFLIPOCT exists"
else
#---exe---#
message " Y-Flipping neurons first "
$Vaa3D -x ireg -f yflip -i $NEURONS -o $NEURONSYFLIP
$Vaa3D -x ireg -f convertDatatype -i $NEURONSYFLIP -o $NEURONSYFLIPOCT -p "#t 1 #k 1"
echo ""
fi

if(($CHN>0))
then
SUBRAWCI=${OUTPUT}"/subbrain_c0.v3draw"
fi

if(($CHN>1))
then
SUBRAWCII=${OUTPUT}"/subbrain_c1.v3draw"
fi

if(($CHN>2))
then
SUBRAWCIII=${OUTPUT}"/subbrain_c2.v3draw"
fi

if ( is_file_exist "$SUBRAWCI" )
then
echo " SUBRAWCI: $SUBRAWCI exists"
else
#---exe---#
message " Split colors "
$Vaa3D -x ireg -f splitColorChannels -i $SUBBRAW
fi

SUBNEU=${OUTPUT}"/subbrainneu.v3draw"


if ( is_file_exist "$SUBNEU" )
then
echo " SUBNEU: $SUBNEU exists"
else
#---exe---#
message " Merge brain and neurons into one image stack "

if(($CHN==1))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBRAWCI $NEURONSYFLIPOCT -o $SUBNEU
fi

if(($CHN==2))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBRAWCI $SUBRAWCII $NEURONSYFLIPOCT -o $SUBNEU
fi

if(($CHN==3))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBRAWCI $SUBRAWCII $SUBRAWCIII $NEURONSYFLIPOCT -o $SUBNEU
fi

fi

NEUCH=$CHN
CHN=$((CHN+1));

message "$NEUCH $CHN"

### shrinkage ratio
# VECTASHIELD/DPXEthanol = 0.82
# VECTASHIELD/DPXPBS = 0.86
DPXSHRINKRATIO=1.0

if [[ $MP =~ "Vector Shield Mounting" ]]
then
    DPXSHRINKRATIO=1.0
elif [[ $MP =~ "DPX Ethanol Mounting" ]]
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

RESTX_X=`echo $DPXSHRINKRATIO*$RESTX_X | bc -l`
RESTX_Y=`echo $DPXSHRINKRATIO*$RESTX_Y | bc -l`
RESTX_Z=`echo $DPXSHRINKRATIO*$RESTX_Z | bc -l`

DPXRI=1.55

### isotropic interpolation
SRX=`echo $RESX/$RESTX_X | bc -l`
SRY=`echo $RESY/$RESTX_Y | bc -l`
SRZ=`echo $RESZ/$RESTX_Z | bc -l`
#SRZ=`echo $SRZ*$DPXRI | bc -l`

### isotropic
SUBTXIS=${OUTPUT}"/subtxIS.v3draw"

if ( is_file_exist "$SUBTXIS" )
then
echo " SUBTXIS: $SUBTXIS exists"
else
#---exe---#
message " Isotropic sampling 20x subject "
$Vaa3D -x ireg -f isampler -i $SUBNEU -o $SUBTXIS -p "#x $SRX #y $SRY #z $SRZ #i 1"
fi

SUBTXPP=${OUTPUT}"/subtxPP.v3draw"

if ( is_file_exist "$SUBTXPP" )
then
echo " SUBTXPP: $SUBTXPP exists"
else
#---exe---#
message " Resizing the 20x subject "
$Vaa3D -x ireg -f prepare20xData -o $SUBTXPP -p "#s $SUBTXIS #t $TAR #k 1"
fi

SUBREF=$((SUBREF-1));
TARREF=$((TARREF-1));

##################
# Alignment
##################

#
### global alignment
#

JBAPARA="-B 1280 -H 2 -n 1"

message " Global alignment "

SUBTXGA=${OUTPUT}"/subtxGlobalAligned.v3draw"

if ( is_file_exist "$SUBTXGA" )
then
echo " SUBTXGA: $SUBTXGA exists"
else
#---exe---#
message " Global aligning the 20x subject "
$JBA -t $TAR -C $TARREF -s $SUBTXPP -c $SUBREF -w 0 -o $SUBTXGA -B 1280 -H 2 -n 1
fi

if(($CHN>0))
then
SUBTXGACI=${OUTPUT}"/subtxGlobalAligned_c0.v3draw"
SUBTXLACI=${OUTPUT}"/subtxLocalAligned_c0.v3draw"
fi

if(($CHN>1))
then
SUBTXGACII=${OUTPUT}"/subtxGlobalAligned_c1.v3draw"
SUBTXLACII=${OUTPUT}"/subtxLocalAligned_c1.v3draw"
fi

if(($CHN>2))
then
SUBTXGACIII=${OUTPUT}"/subtxGlobalAligned_c2.v3draw"
SUBTXLACIII=${OUTPUT}"/subtxLocalAligned_c2.v3draw"
fi

if(($CHN>3))
then
SUBTXGACIV=${OUTPUT}"/subtxGlobalAligned_c3.v3draw"
SUBTXLACIV=${OUTPUT}"/subtxLocalAligned_c3.v3draw"
fi

SUBTXGACR=${OUTPUT}"/subtxGlobalAligned_c"${SUBREF}".v3draw"
SUBTXLACR=${OUTPUT}"/subtxLocalAligned_c"${SUBREF}".v3draw"

NEULACR=${OUTPUT}"/subtxLocalAligned_c"${NEUCH}".v3draw"

if ( is_file_exist "$SUBTXGACR" )
then
echo " SUBTXGACR: $SUBTXGACR exists"
else
#---exe---#
message " Splitting the color channels of the global aligned 20x subject "
$Vaa3D -x ireg -f splitColorChannels -i $SUBTXGA
fi

message " Local alignment "

if ( is_file_exist "$SUBTXLACR" )
then
echo " SUBTXLACR: $SUBTXLACR exists"
else
#---exe---#
message " Local aligning the 20x subject "
$JBA -t $TAR -s $SUBTXGACR -w 10 -o $SUBTXLACR -L $TARMARKER -B 1280 -H 2 -n 1
fi

CSVT=$SUBTXLACR"_target.csv"
CSVS=$SUBTXLACR"_subject.csv"

if(($CHN>1 && $SUBREF!=0))
then
$JBA -t $TAR -s $SUBTXGACI -w 10 -o $SUBTXLACI -L $CSVT -l $CSVS -B 1280 -H 2 -n 1
fi

if(($CHN>1 && $SUBREF!=1))
then
$JBA -t $TAR -s $SUBTXGACII -w 10 -o $SUBTXLACII -L $CSVT -l $CSVS -B 1280 -H 2 -n 1
fi

if(($CHN>2 && $SUBREF!=2))
then
$JBA -t $TAR -s $SUBTXGACIII -w 10 -o $SUBTXLACIII -L $CSVT -l $CSVS -B 1280 -H 2 -n 1
fi

if(($CHN>3 && $SUBREF!=3))
then
$JBA -t $TAR -s $SUBTXGACIV -w 10 -o $SUBTXLACIV -L $CSVT -l $CSVS -B 1280 -H 2 -n 1
fi

CHN=$((CHN-1));
message "$NEUCH $CHN"

SUBTXLA=${OUTPUT}"/subtxLocalAligned.v3draw"

if ( is_file_exist "$SUBTXLA" )
then
echo " SUBTXLA: $SUBTXLA exists"
else
#---exe---#
message " Merging aligned colors into one image stack "

if(($CHN>0))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBTXLACI -o $SUBTXLA
fi

if(($CHN>1))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBTXLACI $SUBTXLACII -o $SUBTXLA
fi

if(($CHN>2))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBTXLACI $SUBTXLACII $SUBTXLACIII -o $SUBTXLA
fi

if(($CHN>3))
then
$Vaa3D -x ireg -f mergeColorChannels -i $SUBTXLACI $SUBTXLACII $SUBTXLACIII $SUBTXLACIV -o $SUBTXLA
fi

fi


SUBTXALIGNED=${FINALOUTPUT}"/AlignedFlyBrain.v3draw"

if ( is_file_exist "$SUBTXALIGNED" )
then
echo " SUBTXALIGNED: $SUBTXALIGNED exists"
else
#---exe---#
message " Local aligning the 20x subject "
$Vaa3D -x ireg -f prepare20xData -o $SUBTXALIGNED -p "#s $SUBTXLA #t $ATLAS"
fi

NEUALIGNED=${OUTPUT}"/AlignedNeuron_yflip.v3draw"
NEUALIGNEDYFLIP=${OUTPUT}"/AlignedNeuron.v3draw"

NEURON_MASKS_FILENAME="ConsolidatedLabelBrain.v3draw"
FINAL_ALIGNED_NEURON_FILE_PATH="${FINALOUTPUT}/${NEURON_MASKS_FILENAME}"

if ( is_file_exist "$NEUALIGNEDYFLIP" )
then
echo " NEUALIGNEDYFLIP: $NEUALIGNEDYFLIP exists"
else
#---exe---#
message " resize and flip neuron "
$Vaa3D -x ireg -f prepare20xData -o $NEUALIGNED -p "#s $NEULACR #t $ATLAS #k 1"
$Vaa3D -x ireg -f yflip -i $NEUALIGNED -o $NEUALIGNEDYFLIP
fi

if ( is_file_exist "$FINAL_ALIGNED_NEURON_FILE_PATH" )
then
echo " FINAL_ALIGNED_NEURON_FILE_PATH: $FINAL_ALIGNED_NEURON_FILE_PATH exists"
else
#---exe---#
message " convert to 16bit v3dpbd "
$Vaa3D -x ireg -f convertDatatype -i $NEUALIGNEDYFLIP -o $FINAL_ALIGNED_NEURON_FILE_PATH -p "#t 2 #k 1"
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
$Vaa3D -x ireg -f esimilarity -o $AQ -p "#s $SUBTXALIGNED #cs $SUBREF #t $ATLAS"
fi

while read LINE
do
read SCORE
done < $AQ; 

QISCOREFILE=${FINALOUTPUT}"/QiScore.csv"

if ( is_file_exist "$QISCOREFILE" )
then
echo " QISCOREFILE: $QISCOREFILE exists"
else
#---exe---#
message " Calculating Qi scores "
$Vaa3D -x ireg -f QiScoreStas -o $QISCOREFILE -p "#l $CSVT #t $TARMARKER #m $LCRMASK" 
fi

while read LINE
do
read QISCORE
done < $QISCOREFILE;

if [[ -f "$SUBTXALIGNED" ]]; then
META=${FINALOUTPUT}"/AlignedFlyBrain.properties"
echo "alignment.stack.filename=AlignedFlyBrain.v3draw" >> $META
echo "alignment.image.channels=$INPUT1_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT1_REF" >> $META
echo "alignment.space.name=$UNIFIED_SPACE" >> $META
echo "alignment.resolution.voxels=0.62x0.62x0.62" >> $META
echo "alignment.image.size=1024x512x218" >> $META
echo "alignment.objective=20x" >> $META
echo "default=true" >> $META
if [[ -f "$FINAL_ALIGNED_NEURON_FILE_PATH" ]]; then
echo "neuron.masks.filename=${NEURON_MASKS_FILENAME}" >> $META
fi
echo "alignment.quality.score.ncc=$SCORE" >> $META
echo "alignment.quality.score.qi=$QISCORE" >> $META
fi


