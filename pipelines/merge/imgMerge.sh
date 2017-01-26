#!/bin/bash
#
# two scanned images merging pipeline
#

DIR=$(cd "$(dirname "$0")"; pwd)

####
# TOOLKITS
####

Vaa3D="$DIR/../Toolkits/Vaa3D/vaa3d"
ANTS="$DIR/../Toolkits/ANTS/ANTS"
WARP="$DIR/../Toolkits/ANTS/WarpImageMultiTransform"
SAMPLE="$DIR/../Toolkits/ANTS/ResampleImageBySpacing"

####
# Inputs
####

INPUT1=""
INPUT2=""
FINAL_OUTPUT=""
MULTISCAN_BLEND_VERSION=""

while getopts "o:m:h" opt
do case "$opt" in
    o)  FINAL_OUTPUT="$OPTARG";;
    m)  MULTISCAN_BLEND_VERSION="$OPTARG";;
    h) echo "Usage: $0 [-o output_file] [-m multiscanblend_version] input1.lsm input2.lsm" >&2
        exit 1;;
    esac
done
shift $((OPTIND-1))

INPUT1="$1"
INPUT2="$2"

FINAL_DIR=${FINAL_OUTPUT%/*}
FINAL_STUB=${FINAL_OUTPUT%.*}
EXT=${FINAL_OUTPUT##*.}

export TMPDIR="$FINAL_DIR"
WORKING_DIR=`mktemp -d`
OUTPUT="$WORKING_DIR/merged.v3draw"
FILEPATH=$WORKING_DIR
FILETRNSTYPE="$FILEPATH/TransformationType.txt"

echo "Run Dir: $DIR"
echo "Working Dir: $WORKING_DIR"
echo "Output Dir: $FINAL_DIR"
echo "Input 1: $INPUT1"
echo "Input 2: $INPUT2"
echo "Multiscan Blend Version: multiscanblend$MULTISCAN_BLEND_VERSION"

cd $WORKING_DIR

if [ "$INPUT2" == "null" ]
then
    MERGED="$WORKING_DIR/output.${EXT}"
    echo "~ Converting single LSM file to: $MERGED"
    $Vaa3D -cmd image-loader -convert $INPUT1 $MERGED
    OUTPUT=$MERGED
else 

    ####
    # detect transformation type
    ####

    $Vaa3D -x multiscanstacks.so -f transformdet -i "$INPUT1" "$INPUT2" -o "$FILETRNSTYPE"

    ####
    # merge
    ####

    echo ""
    count=0
    cat $FILETRNSTYPE | while read LINE
    do

        if [ "$LINE" == "# Transformation Type File: V1.0" -a "$count" == 0 ];
        then
        
            echo "Loading $LINE"

        elif [ $count = 1 ]; 
        then
            
            TYPE="$LINE"

            if [ "$TYPE" = "0 rigid transformations." ]
            then
                echo "$TYPE"

                # merge images using rigid translations
                $Vaa3D -x multiscanstacks.so -f multiscanblend$MULTISCAN_BLEND_VERSION -i "$INPUT1" "$INPUT2" -o "$OUTPUT"

            elif [ "$TYPE" = "1 non-rigid transformations." ];
            then
                echo "$TYPE"

                # merge images using non-rigid transformations
                FILETEMP=$FILEPATH"/tmp.v3draw"

                echo "~ Running extractchannels"
                $Vaa3D -x multiscanstacks.so -f extractchannels -i "$INPUT1" "$INPUT2" -o "$FILETEMP"
                FIXED0=$FILEPATH"/target_ref.v3draw"
                MOVING0=$FILEPATH"/subject_ref.v3draw"
                SUBJECT0=$FILEPATH"/subject_signal.v3draw"

                echo "~ Running NiftiImageConverter on $FIXED0"
                $Vaa3D -x ireg.so -f NiftiImageConverter -i $FIXED0
                FIXED=$FILEPATH"/target_ref_c0.nii"

                echo "~ Running NiftiImageConverter on $MOVING0"
                $Vaa3D -x ireg.so -f NiftiImageConverter -i $MOVING0
                MOVING=$FILEPATH"/subject_ref_c0.nii"

                echo "~ Running NiftiImageConverter on $SUBJECT0"
                $Vaa3D -x ireg.so -f NiftiImageConverter -i $SUBJECT0
                SUBJECT=$FILEPATH"/subject_signal_c0.nii"

                FIXEDDS=$FILEPATH"/target_ref_ds.nii"
                MOVINGDS=$FILEPATH"/subject_ref_ds.nii"
                SAMPLERATIO=4
                echo "~ Running $SAMPLE on $FIXED"
                $SAMPLE 3 $FIXED $FIXEDDS $SAMPLERATIO $SAMPLERATIO $SAMPLERATIO
                echo "~ Running $SAMPLE on $MOVING"
                $SAMPLE 3 $MOVING $MOVINGDS $SAMPLERATIO $SAMPLERATIO $SAMPLERATIO

                SIMMETRIC=$FILEPATH"/cc"
                AFFINEMATRIX=$FILEPATH"/ccAffine.txt"
                FWDDISPFIELD=$FILEPATH"/ccWarp.nii.gz"
                BWDDISPFIELD=$FILEPATH"/ccInverseWarp.nii.gz"
                MAXITERS=30x90x20
                echo "~ Running $ANTS on $MOVING"
                $ANTS 3 -m  CC[ $FIXEDDS, $MOVINGDS, 1, 4]  -t SyN[0.25]  -r Gauss[3,0] -o $SIMMETRIC --use-Histogram-Matching  -i $MAXITERS --number-of-affine-iterations  10000x10000x10000x10000x10000 --MI-option 32x16000

                DEFORMED=$FILEPATH"/subject_signal_warped.nii"
                echo "~ Running $WARP on $SUBJECT"
                $WARP 3 $SUBJECT $DEFORMED -R $FIXED $FWDDISPFIELD $AFFINEMATRIX --use-BSpline

                DEFORMEDV3DRAW=$FILEPATH"/subject_signal_warped.v3draw"
                echo "~ Running NiftiImageConverter on $DEFORMED"
                $Vaa3D -x ireg.so -f NiftiImageConverter -i $DEFORMED -p "#b 1"

                echo "~ Running multiscanblend"
                $Vaa3D -x multiscanstacks.so -f multiscanblend$MULTISCAN_BLEND_VERSION -i "$INPUT1" "$INPUT2" $DEFORMEDV3DRAW -o "$OUTPUT" -p "#d 1"

            else
                echo "Invalid Transformations: '$TYPE'"
            fi

        else
            echo "Exit."
        fi

        let count++
    done

    if [ "$EXT" == "v3dpbd" ]
    then
        MERGED_COMPRESSED="$WORKING_DIR/merged.v3dpbd"
        echo "~ Compressing output file to PBD: $MERGED_COMPRESSED"
        $Vaa3D -cmd image-loader -convert $OUTPUT $MERGED_COMPRESSED
        OUTPUT=$MERGED_COMPRESSED
    fi

fi

echo "~ Moving output to final location: $FINAL_OUTPUT"
mv $OUTPUT $FINAL_OUTPUT
mv $FILETRNSTYPE "$FINAL_STUB-tt.txt"

echo "~ Removing working directory $WORKING_DIR"
rm -rf $WORKING_DIR

echo ""

