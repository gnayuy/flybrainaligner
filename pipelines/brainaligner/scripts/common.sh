#!/bin/bash
#
# Common functions for use in alignment scripts.
#

export UNIFIED_SPACE="Unified 20x Alignment Space"

readItemFromConf()
{
    local FILE="$1"
    local ITEM="$2"
    VAL=`grep "<$ITEM>.*<.$ITEM>" $FILE | sed -e "s/^.*<$ITEM/<$ITEM/" | cut -f2 -d">"| cut -f1 -d"<"`
    echo ${VAL}
}

#
# This was supposed to be an alternative to getopts that works with optional arguments.
# That part works, but it does not support spaces in arguments. It's not trivial to fix, 
# but I may come back to this later and make it work. For now it is unused.
#
parseArg()
{
    local result_var="$1"
    local arg_name="$2"
    shift 2
    local args="$@"
    local ret_next=false
    for arg in ${args[*]}
    do
        echo "$arg"
        if $ret_next ; then
            eval $result_var="'$arg'"
            return;
        fi
        if [ "-${arg_name}" == "${arg}" ]; then
            ret_next=true;
        fi
    done
}

parseParameters() 
{
    while getopts ":c:t:k:w:s:i:j:m:e:f:g:z:h" opt
    do case "$opt" in
        c) CONFIG_FILE="$OPTARG";;
        t) TEMPLATE_DIR="$OPTARG";;
        k) TOOL_DIR="$OPTARG";;
        w) WORK_DIR="$OPTARG";;
        i) INPUT1="$OPTARG";;
        j) INPUT2="$OPTARG";;
        s) STEP="$OPTARG";;
        m) MOUNTING_PROTOCOL="$OPTARG";;
        e) INPUT1_NEURONS="$OPTARG";;
        f) INPUT2_NEURONS="$OPTARG";;
	g) GENDER="$OPTARG";;
	z) ZFLIP="$OPTARG";;
        h) echo "Usage: $0 [-c configuration_file] [-t templates_dir] [-k toolkits_dir] [-w work_dir] [-s step] [-i first_input,num_channels,ref_channel,voxel_sizes,image_size] [-j second_input,num_channels,ref_channel,voxel_sizes,image_size] [-m mounting_protocol] [-e first_input_neurons] [-f second_input_neurons] [-g gender] [-z zflip]" >&2
            exit 1;;
        esac
    done
    shift $((OPTIND-1))

    IFS="," 
    read -ra INPUT1_ARRAY <<< "$INPUT1"
    read -ra INPUT2_ARRAY <<< "$INPUT2"

    INPUT1_FILE=${INPUT1_ARRAY[0]}
    INPUT1_CHANNELS=${INPUT1_ARRAY[1]}
    INPUT1_REF=${INPUT1_ARRAY[2]}
    INPUT1_RES=${INPUT1_ARRAY[3]}
    INPUT1_DIMS=${INPUT1_ARRAY[4]}
 
    INPUT2_FILE=${INPUT2_ARRAY[0]}
    INPUT2_CHANNELS=${INPUT2_ARRAY[1]}
    INPUT2_REF=${INPUT2_ARRAY[2]}
    INPUT2_RES=${INPUT2_ARRAY[3]}
    INPUT2_DIMS=${INPUT2_ARRAY[4]}

    INPUT1_RESX=$(echo $INPUT1_RES | cut -f1 -d'x')
    INPUT1_RESY=$(echo $INPUT1_RES | cut -f2 -d'x')
    INPUT1_RESZ=$(echo $INPUT1_RES | cut -f3 -d'x')
    INPUT1_DIMX=$(echo $INPUT1_DIMS | cut -f1 -d'x')
    INPUT1_DIMY=$(echo $INPUT1_DIMS | cut -f2 -d'x')
    INPUT1_DIMZ=$(echo $INPUT1_DIMS | cut -f3 -d'x')

    INPUT2_RESX=$(echo $INPUT2_RES | cut -f1 -d'x')
    INPUT2_RESY=$(echo $INPUT2_RES | cut -f2 -d'x')
    INPUT2_RESZ=$(echo $INPUT2_RES | cut -f3 -d'x')
    INPUT2_DIMX=$(echo $INPUT2_DIMS | cut -f1 -d'x')
    INPUT2_DIMY=$(echo $INPUT2_DIMS | cut -f2 -d'x')
    INPUT2_DIMZ=$(echo $INPUT2_DIMS | cut -f3 -d'x')
}

message()
{
    echo ""
    echo " ~ DEBUG: ${1} ~ "
    echo ""
}

is_file_exist()
{
    local f="$1"
    [[ -f "$f" ]] && return 0 || return 1
}

checkInputs()
{
   if ( is_file_exist "$1" );
   then
       message "$1 exists"
   else
       message "Input $1 does not exist!";
       exit 1;
   fi
}

ensureRawFile()
{
    local _Vaa3D="$1"
    local _WORKING_DIR="$2"
    local _FILE="$3"
    local _RESULTVAR="$4"
    local _EXT=${_FILE#*.}
    if [ "$_EXT" != "v3draw" ] && [ "$_EXT" != "raw" ] ; then
        local _PBD_FILE=$_FILE
        local _FILE_STUB=`basename $_PBD_FILE`
        _FILE="$_WORKING_DIR/${_FILE_STUB%.*}.v3draw"
        echo "Converting input file to V3DRAW format"
        $_Vaa3D -cmd image-loader -convert "$_PBD_FILE" "$_FILE"
    fi
    eval $_RESULTVAR="'$_FILE'"
}

ensureRawFileWdiffName()
{
    local _Vaa3D="$1"
    local _WORKING_DIR="$2"
    local _FILE="$3"
    local _OUTFILE="$4"
    local _RESULTVAR="$5"
    local _EXT=${_FILE#*.}

    if [ "$_EXT" == "v3dpbd" ]; 
    then
        local _FILE_STUB=`basename $_OUTFILE`
        _OUTFILE="$_WORKING_DIR/${_FILE_STUB%.*}.v3draw"
    if ( is_file_exist "$_OUTFILE" )
        then
            echo "_OUTFILE: $_OUTFILE exists."
        else
            message "Converting PBD to RAW format"
            $_Vaa3D -cmd image-loader -convert "$_FILE" "$_OUTFILE"
        fi
    
     elif [ "$_EXT" == "v3draw" ];
     then
        local _FILE_STUB=`basename $_OUTFILE`
        _OUTFILE="$_WORKING_DIR/${_FILE_STUB}"
        if ( is_file_exist "$_OUTFILE" )
        then
            echo "_OUTFILE: $_OUTFILE exists."
        else
            message "Creating symbolic link to neuron"
            ln -s "$_FILE" "$_OUTFILE"
        fi
     fi
    
    eval $_RESULTVAR="'$_OUTFILE'"
}


