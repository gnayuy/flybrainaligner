#!/bin/bash

#
# transform aligned right optic lobe from Yoshi template space to Arnim template space pipeline
# version 1.0, 2013/10/14
#

################################################################################
#
# Target brain's resolution (63x 0.38x0.38x0.38 um and 20x 0.62x0.62x0.62 um)
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

SUBREF=$INPUT1_FILE
SUBSIG=$INPUT2_FILE
NEURONS=$INPUT1_NEURONS

# tools
Vaa3D=`readItemFromConf $CONFIGFILE "Vaa3D"`
JBA=`readItemFromConf $CONFIGFILE "JBA"`

Vaa3D=${TOOLDIR}"/"${Vaa3D}
JBA=${TOOLDIR}"/"${JBA}

# templates
TARIS=`readItemFromConf $CONFIGFILE "tgtFBSXRECDPXRS"`
TARAS=`readItemFromConf $CONFIGFILE "tgtFBSXRECDPX"`

AFFINEMAT=`readItemFromConf $CONFIGFILE "wfYTOA"`
YMARKERSX=`readItemFromConf $CONFIGFILE "wfYSXmarkers"`
AMARKERSX=`readItemFromConf $CONFIGFILE "wfASXmarkers"`

CROPCONF=`readItemFromConf $CONFIGFILE "FROLCROPMATRIX"`
ROTMATRIX=`readItemFromConf $CONFIGFILE "FROLROTMATRIX"`
INVROTMATRIX=`readItemFromConf $CONFIGFILE "FROLINVROTMATRIX"`

TARIS=${TMPLDIR}"/"${TARIS}
TARAS=${TMPLDIR}"/"${TARAS}

AFFINEMAT=${TMPLDIR}"/"${AFFINEMAT}
YMARKERSX=${TMPLDIR}"/"${YMARKERSX}
AMARKERSX=${TMPLDIR}"/"${AMARKERSX}

CROPCONF=${TMPLDIR}"/"${CROPCONF}
ROTMATRIX=${TMPLDIR}"/"${ROTMATRIX}
INVROTMATRIX=${TMPLDIR}"/"${INVROTMATRIX}

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "WORKDIR: $WORKDIR"
echo "SUBSIG: $SUBSIG"
echo "SUBREF: $SUBREF"
echo "NEURONS: $NEURONS"
message "Vars..."
echo "Vaa3D: $Vaa3D"
echo "JBA: $JBA"
echo "TARIS: $TARIS"
echo "TARAS: $TARAS"
echo "AFFINEMAT: $AFFINEMAT"
echo "YMARKERSX: $YMARKERSX"
echo "AMARKERSX: $AMARKERSX"
echo "CROPCONF: $CROPCONF"
echo "ROTMATRIX: $ROTMATRIX"
echo "INVROTMATRIX: $INVROTMATRIX"
echo ""

OUTPUT=$WORKDIR"/Outputs"
FINALOUTPUT=$WORKDIR"/ArnimSxSpace"

if [ ! -d $OUTPUT ]; then
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then
mkdir $FINALOUTPUT
fi

# convert inputs to raw format
ensureRawFile "$Vaa3D" "$OUTPUT" "$SUBSIG" SUBSIG
echo "RAW SUBSIG: $SUBSIG"

ensureRawFile "$Vaa3D" "$OUTPUT" "$SUBREF" SUBREF
echo "RAW SUBREF: $SUBREF"

ensureRawFile "$Vaa3D" "$OUTPUT" "$NEURONS" NEURONS
echo "RAW NEURONS: $NEURONS"

SRTSX=2.4493
SRTSY=2.4493
SRTSZ=4

YSXRECDIMX=3135
YSXRECDIMY=2508
YSXRECDIMZ=1024

YTTXUSDIMX=1567
YTTXUSDIMY=1254
YTTXUSDIMZ=512

SRYTAX=1.0926
SRYTAY=1.0926
SRYTAZ=0.961

##################
# Warping
##################


### step 1 yflip neurons
SUBSIGYF=${OUTPUT}"/subsigyflip.v3draw"
NEURONYF=${OUTPUT}"/neuronyflip.v3draw"

if ( is_file_exist "$SUBSIGYF" )
then
echo "SUBSIGYF: $SUBSIGYF exists"
else
#---exe---#
message " Step 0 yflip signals "
$Vaa3D -x ireg -f yflip -i $SUBSIG -o $SUBSIGYF
fi

if ( is_file_exist "$NEURONYF" )
then
echo "NEURONYF: $NEURONYF exists"
else
#---exe---#
message " Step 0 yflip neurons "
$Vaa3D -x ireg -f yflip -i $NEURONS -o $NEURONYF
fi

### step 2 resize image
SUBREFRS=${OUTPUT}"/subrefrs.v3draw"
SUBSIGRS=${OUTPUT}"/subsigrs.v3draw"

NEURONRS=${OUTPUT}"/neuronyrs.v3draw"

if ( is_file_exist "$SUBREFRS" )
then
echo "SUBREFRS: $SUBREFRS exists"
else
#---exe---#
message " step 2 resize SUBREF"
$Vaa3D -x ireg -f prepare20xData -o $SUBREFRS -p "#s $SUBREF #t $TARAS"
fi

if ( is_file_exist "$SUBSIGRS" )
then
echo "SUBSIGRS: $SUBSIGRS exists"
else
#---exe---#
message " step 2 resize SUBSIG"
$Vaa3D -x ireg -f prepare20xData -o $SUBSIGRS -p "#s $SUBSIGYF #t $TARAS"
fi

if ( is_file_exist "$NEURONRS" )
then
echo "NEURONRS: $NEURONRS exists"
else
#---exe---#
message " step 2 resize NEURONYF"
$Vaa3D -x ireg -f prepare20xData -o $NEURONRS -p "#s $NEURONYF #t $TARAS #k 1"
fi

### step 3 global align
SUBREFGA=${OUTPUT}"/subrefrsga.v3draw"
SUBSIGGA=${OUTPUT}"/subsigrsga.v3draw"

NEURONGA=${OUTPUT}"/neuronyrsga.v3draw"

if ( is_file_exist "$SUBREFGA" )
then
echo "SUBREFGA: $SUBREFGA exists"
else
#---exe---#
message " step 3 global algined SUBREFRS"
$Vaa3D -x ireg -f iwarp2 -o $SUBREFGA -p "#s $SUBREFRS #a $AFFINEMAT #sx $SRTSX #sy $SRTSY #sz $SRTSZ #dx $YSXRECDIMX #dy $YSXRECDIMY #dz $YSXRECDIMZ"
fi

if ( is_file_exist "$SUBSIGGA" )
then
echo "SUBSIGGA: $SUBSIGGA exists"
else
#---exe---#
message " step 3 global algined SUBSIGRS"
$Vaa3D -x ireg -f iwarp2 -o $SUBSIGGA -p "#s $SUBSIGRS #a $AFFINEMAT #sx $SRTSX #sy $SRTSY #sz $SRTSZ #dx $YSXRECDIMX #dy $YSXRECDIMY #dz $YSXRECDIMZ"
fi

if ( is_file_exist "$NEURONGA" )
then
echo "NEURONGA: $NEURONGA exists"
else
#---exe---#
message " step 3 global algined NEURONRS"
$Vaa3D -x ireg -f iwarp2 -o $NEURONGA -p "#s $NEURONRS #a $AFFINEMAT #sx $SRTSX #sy $SRTSY #sz $SRTSZ #dx $YSXRECDIMX #dy $YSXRECDIMY #dz $YSXRECDIMZ #i 1"
fi

### step 4 downsample (0.19 um -> 0.38 um)
SUBREFDS=${OUTPUT}"/subrefrsgads.v3draw"
SUBSIGDS=${OUTPUT}"/subsigrsgads.v3draw"

NEURONDS=${OUTPUT}"/neuronyrsgads.v3draw"

if ( is_file_exist "$SUBREFDS" )
then
echo "SUBREFDS: $SUBREFDS exists"
else
#---exe---#
message " step 4 downsample SUBREFGA"
$Vaa3D -x ireg -f isampler -i $SUBREFGA -o $SUBREFDS -p "#x 0.5 #y 0.5 #z 0.5"
fi

if ( is_file_exist "$SUBSIGDS" )
then
echo "SUBSIGDS: $SUBSIGDS exists"
else
#---exe---#
message " step 4 downsample SUBSIGGA"
$Vaa3D -x ireg -f isampler -i $SUBSIGGA -o $SUBSIGDS -p "#x 0.5 #y 0.5 #z 0.5"
fi

if ( is_file_exist "$NEURONDS" )
then
echo "NEURONDS: $NEURONDS exists"
else
#---exe---#
message " step 4 downsample NEURONGA"
$Vaa3D -x ireg -f isampler -i $NEURONGA -o $NEURONDS -p "#x 0.5 #y 0.5 #z 0.5 #i 1"
fi

### step 5 local align
SUBREFLA=${OUTPUT}"/subrefrsgadsla.v3draw"
SUBSIGLA=${OUTPUT}"/subsigrsgadsla.v3draw"

NEURONLA=${OUTPUT}"/neuronyrsgadsla.v3draw"

if ( is_file_exist "$SUBREFLA" )
then
echo "SUBREFLA: $SUBREFLA exists"
else
#---exe---#
message " step 5 local aligned SUBREFDS"
$JBA -t $TARIS -s $SUBREFDS -w 10 -o $SUBREFLA -L $AMARKERSX -l $YMARKERSX -B 1567 -H 2
fi

if ( is_file_exist "$SUBSIGLA" )
then
echo "SUBSIGLA: $SUBSIGLA exists"
else
#---exe---#
message " step 5 local aligned SUBSIGDS"
$JBA -t $TARIS -s $SUBSIGDS -w 10 -o $SUBSIGLA -L $AMARKERSX -l $YMARKERSX -B 1567 -H 2
fi

if ( is_file_exist "$NEURONLA" )
then
echo "NEURONLA: $NEURONLA exists"
else
#---exe---#
message " step 5 local aligned NEURONDS"
$JBA -t $TARIS -s $NEURONDS -w 10 -o $NEURONLA -L $AMARKERSX -l $YMARKERSX -B 1567 -H 2 -n 1
fi

### step 6 resample from Y space to A space
SUBREFRS=${OUTPUT}"/subrefrsgadslars.v3draw"
SUBSIGRS=${OUTPUT}"/subsigrsgadslars.v3draw"

NEURONRS=${OUTPUT}"/neuronyrsgadslars.v3draw"

if ( is_file_exist "$SUBREFRS" )
then
echo "SUBREFRS: $SUBREFRS exists"
else
#---exe---#
message " step 6 resample SUBREFLA"
$Vaa3D -x ireg -f isampler -i $SUBREFLA -o $SUBREFRS -p "#x $SRYTAX #y $SRYTAY #z $SRYTAZ"
fi

if ( is_file_exist "$SUBSIGRS" )
then
echo "SUBSIGRS: $SUBSIGRS exists"
else
#---exe---#
message " step 6 resample SUBSIGLA"
$Vaa3D -x ireg -f isampler -i $SUBSIGLA -o $SUBSIGRS -p "#x $SRYTAX #y $SRYTAY #z $SRYTAZ"
fi

if ( is_file_exist "$NEURONRS" )
then
echo "NEURONRS: $NEURONRS exists"
else
#---exe---#
message " step 6 resample NEURONLA"
$Vaa3D -x ireg -f isampler -i $NEURONLA -o $NEURONRS -p "#x $SRYTAX #y $SRYTAY #z $SRYTAZ #i 1"
fi

### step 7 rotate
SUBREFRT=${OUTPUT}"/subrefrsgadslarsrt.v3draw"
SUBSIGRT=${OUTPUT}"/subsigrsgadslarsrt.v3draw"

NEURONRT=${OUTPUT}"/neuronyrsgadslarsrt.v3draw"

if ( is_file_exist "$SUBREFRT" )
then
echo "SUBREFRT: $SUBREFRT exists"
else
#---exe---#
message " step 7 rotate SUBREFRS"
$Vaa3D -x ireg -f iwarp  -o $SUBREFRT -p "#s $SUBREFRS #t $SUBREFRS #a $ROTMATRIX"
fi

if ( is_file_exist "$SUBSIGRT" )
then
echo "SUBSIGRT: $SUBSIGRT exists"
else
#---exe---#
message " step 7 rotate SUBSIGRS"
$Vaa3D -x ireg -f iwarp  -o $SUBSIGRT -p "#s $SUBSIGRS #t $SUBSIGRS #a $ROTMATRIX"
fi

if ( is_file_exist "$NEURONRT" )
then
echo "NEURONRT: $NEURONRT exists"
else
#---exe---#
message " step 7 rotate NEURONRS"
$Vaa3D -x ireg -f iwarp  -o $NEURONRT -p "#s $NEURONRS #t $NEURONRS #a $ROTMATRIX #i 1"
fi

### step 8 crop
SUBREFCP=${FINALOUTPUT}"/Reference.v3draw"
SUBSIGCP=${OUTPUT}"/subsigrsgadslarsrtcp.v3draw"

NEURONCP=${OUTPUT}"/neuronyrsgadslarsrtcp.v3draw"

if ( is_file_exist "$SUBREFCP" )
then
echo "SUBREFCP: $SUBREFCP exists"
else
#---exe---#
message " step 8 crop SUBREFRT"
$Vaa3D -x ireg -f cropImage -i $SUBREFRT -o $SUBREFCP -p "#m $CROPCONF"
fi

if ( is_file_exist "$SUBSIGCP" )
then
echo "SUBSIGCP: $SUBSIGCP exists"
else
#---exe---#
message " step 8 crop SUBSIGRT"
$Vaa3D -x ireg -f cropImage -i $SUBSIGRT -o $SUBSIGCP -p "#m $CROPCONF"
fi

if ( is_file_exist "$NEURONCP" )
then
echo "NEURONCP: $NEURONCP exists"
else
#---exe---#
message " step 8 rotate NEURONRT"
$Vaa3D -x ireg -f cropImage -i $NEURONRT -o $NEURONCP -p "#m $CROPCONF"
fi

### step 9 yflip signals and neurons
SUBSIGYF=${FINALOUTPUT}"/CosolidatedSignal.v3draw"

if ( is_file_exist "$SUBSIGYF" )
then
echo "SUBSIGYF: $SUBSIGYF exists"
else
#---exe---#
message " Step 9 yflip signals "
$Vaa3D -x ireg -f yflip -i $SUBSIGCP -o $SUBSIGYF
fi

NEURONYF=${FINALOUTPUT}"/ConsolidatedLabel.v3draw"

if ( is_file_exist "$NEURONYF" )
then
echo "NEURONYF: $NEURONYF exists"
else
#---exe---#
message " Step 9 yflip neurons "
$Vaa3D -x ireg -f yflip -i $NEURONCP -o $NEURONYF
fi


##################
# Output Meta
##################



