#!/bin/bash
#
# Wrapper script for executing 'configured' alignment pipelines in a temporary directory
#

DIR=$(cd "$(dirname "$0")"; pwd)

SCRIPT_PATH=$1
NUM_THREADS=$2
DEBUG_MODE="release"
OUTPUT_DIR=""
shift 2
ARGS="$@"

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$NUM_THREADS
export FSLOUTPUTTYPE=NIFTI_GZ

while getopts ":o:d:h:" opt
do case "$opt" in
    o)  OUTPUT_DIR="$OPTARG";;
    d)  DEBUG_MODE="$OPTARG";;
    h) echo "Usage: $0 <alignmentScript> [-o output_dir] ..." >&2
        exit 1;;
    esac
done

# Temporary alignment artifacts are too large for local scratch space,
# so we need to keep them on network storage.
WORKING_DIR="$OUTPUT_DIR/temp"
rm -rf $WORKING_DIR
mkdir $WORKING_DIR
cd $WORKING_DIR

echo "~ Alignment Script: $SCRIPT_PATH"
echo "~ Working Dir: $WORKING_DIR"
echo "~ Output Dir: $OUTPUT_DIR"
echo "~ DEBUG_MODE $DEBUG_MODE"

ARGS=`echo $ARGS | sed -e "s/-o \S*/-w ${WORKING_DIR//\//\\/}/"`
ARGS=`echo $ARGS | sed -e "s/-d \S*//"`

echo "~ COMMAND:"
CMD="$SCRIPT_PATH $ARGS"
echo $CMD
eval $CMD

echo "~ Computations complete"
echo "~ Space usage: " `du -h $WORKING_DIR`

echo "~ Moving final output to $OUTPUT_DIR"
mv $WORKING_DIR/FinalOutputs/* $OUTPUT_DIR

if [[ $DEBUG_MODE =~ "debug" ]]
then
echo "~ debugging mode"
else
echo "~ Removing temp directory"
rm -rf $WORKING_DIR
fi

echo "~ Compressing final outputs in: $OUTPUT_DIR"
cd $OUTPUT_DIR
shopt -s nullglob
# Recursively compress all v3draw files, and update propeties files to refer to the new v3dpbd files.
# Most pipelines storage everything at the top level, but there is one alignment pipeline which
# places things in a directory hierarchy, so everything here has to work recursively. 
Vaa3D="$DIR/../Toolkits/Vaa3D/vaa3d"
for fin in $(find . -name "*.v3draw"); do
    fout=${fin%.v3draw}.v3dpbd
    $Vaa3D -cmd image-loader -convert $fin $fout && rm $fin
done
shopt -u nullglob
grep -rl --include=*.properties 'v3draw' ./ | xargs sed -i 's/v3draw/v3dpbd/g'

echo "~ Finished"

