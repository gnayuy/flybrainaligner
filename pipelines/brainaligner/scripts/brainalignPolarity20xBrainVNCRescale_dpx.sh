#!/bin/bash
#
# fly alignment pipeline, version 1.0, 2013/2/15
#

################################################################################
#
# The pipeline is developed for aligning 20x fly (brain + VNC) and then
# rescaling the output back to itensity range of the original input
# Target brain's resolution (0.62x0.62x0.62 um)
#
################################################################################

DIR=$(cd "$(dirname "$0")"; pwd)
. $DIR/common.sh

parseParameters "$@"

Vaa3D=`readItemFromConf $CONFIG_FILE "Vaa3D"`
Vaa3D=${TOOL_DIR}"/"${Vaa3D}
OUTPUT=${WORK_DIR}"/tmp"
FINALOUTPUT=${WORK_DIR}"/FinalOutputs"

echo "~ Executing flyalign20x_dpx_1024px_INT.sh"
$DIR/flyalign20x_dpx_1024px_INT.sh -c $CONFIG_FILE -t $TEMPLATE_DIR -k $TOOL_DIR -w $WORK_DIR -i "$INPUT1" -j "$INPUT2" -m \"$MOUNTING_PROTOCOL\" -e "$INPUT1_NEURONS" -f "$INPUT2_NEURONS" -g $GENDER

FINAL_BRAIN="${FINALOUTPUT}/AlignedFlyBrain.v3draw"
FINAL_BRAIN_PROPS="${FINALOUTPUT}/AlignedFlyBrain.properties"

RESCALED_FILE="${FINALOUTPUT}/AlignedFlyBrainIntRescaled.v3draw"
RESCALED_FILE_PROPS="${FINALOUTPUT}/AlignedFlyBrainIntRescaled.properties"

echo "~ Rescaling intensity range"
$DIR/rescaleIntensityRange.sh -c $CONFIG_FILE -k $TOOL_DIR -w $OUTPUT -s $INPUT1_FILE -i $FINAL_BRAIN -o $RESCALED_FILE

echo "~ Replacing output with rescaled file"
sed -i 's/AlignedFlyBrain/AlignedFlyBrainIntRescaled/' $FINAL_BRAIN_PROPS
mv $FINAL_BRAIN_PROPS $RESCALED_FILE_PROPS
rm $FINAL_BRAIN

