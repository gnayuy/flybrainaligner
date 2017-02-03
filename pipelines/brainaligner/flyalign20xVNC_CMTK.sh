#!/bin/bash
# Program locations: (assumes running this in vnc_align script directory)
#
# 20x fly vnc alignment pipeline using CMTK, version 1.0, June 6, 2013
#

################################################################################
#
# The pipeline is developed for aligning 20x fly vnc using CMTK
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

SUBVNC=$INPUT1_FILE
SUBREF=$INPUT1_REF
CHN=$INPUT1_CHANNELS
GENDER=$GENDER

#MP=$MOUNTING_PROTOCOL

RESX=$INPUT1_RESX
RESY=$INPUT1_RESY
RESZ=$INPUT1_RESZ

# tools
Vaa3D=`readItemFromConf $CONFIGFILE "Vaa3D"`
JBA=`readItemFromConf $CONFIGFILE "JBA"`
ANTS=`readItemFromConf $CONFIGFILE "ANTS"`
WARP=`readItemFromConf $CONFIGFILE "WARP"`
CMTK=`readItemFromConf $CONFIGFILE "CMTK"`
FIJI=`readItemFromConf $CONFIGFILE "Fiji"`
VNCScripts=`readItemFromConf $CONFIGFILE "VNCScripts"`
# add CMTK tools here

Vaa3D=${TOOLDIR}"/"${Vaa3D}
JBA=${TOOLDIR}"/"${JBA}
ANTS=${TOOLDIR}"/"${ANTS}
WARP=${TOOLDIR}"/"${WARP}
CMTK=${TOOLDIR}"/"${CMTK}
FIJI=${TOOLDIR}"/"${FIJI}
VNCScripts=${TOOLDIR}"/"${VNCScripts}"/"


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
VNCTEMPLATEFEMALE=`readItemFromConf $CONFIGFILE "tgtVNC20xAFemale"`
VNCTEMPLATEMALE=`readItemFromConf $CONFIGFILE "tgtVNC20xAMale"`

TAR=${TMPLDIR}"/"${TAR}
ATLAS=${TMPLDIR}"/"${ATLAS}
TARMARKER=${TMPLDIR}"/"${TARMARKER}
LCRMASK=${TMPLDIR}"/"${LCRMASK}
CMPBND=${TMPLDIR}"/"${CMPBND}

if [[ $GENDER =~ "m" ]]
then
# male fly vnc
Tfile=${TMPLDIR}"/"${VNCTEMPLATEMALE}
POSTSCOREMASK=$VNCScripts"VNC_preImageProcessing_Plugins_pipeline/For_Score/Mask_Male_VNC.nrrd"
else
# female fly vnc
Tfile=${TMPLDIR}"/"${VNCTEMPLATEFEMALE}
POSTSCOREMASK=$VNCScripts"VNC_preImageProcessing_Plugins_pipeline/For_Score/flyVNCtemplate20xA_CLAHE_MASK2nd.nrrd"
fi

# debug inputs
message "Inputs..."
echo "CONFIGFILE: $CONFIGFILE"
echo "TMPLDIR: $TMPLDIR"
echo "TOOLDIR: $TOOLDIR"
echo "WORKDIR: $WORKDIR"
echo "SUBVNC: $SUBVNC"
echo "SUBREF: $SUBREF"
echo "MountingProtocol: $MP"
echo "Gender: $GENDER"
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
echo "CMTK: $CMTK"
echo "FIJI: $FIJI"
echo "VNCScripts: $VNCScripts"
echo "TEMPLATE: $Tfile"
echo ""

OUTPUT=${WORKDIR}"/Outputs"
FINALOUTPUT=${WORKDIR}"/FinalOutputs"

if [ ! -d $OUTPUT ]; then 
mkdir $OUTPUT
fi

if [ ! -d $FINALOUTPUT ]; then 
mkdir $FINALOUTPUT
fi

PREPROCIMG=$VNCScripts"VNC_preImageProcessing_Plugins_pipeline/VNC_preImageProcessing_Pipeline_10_21_2015.ijm"
POSTSCORE=$VNCScripts"VNC_preImageProcessing_Plugins_pipeline/For_Score/Score_For_VNC_pipeline.ijm"
RAWCONV=$VNCScripts"raw2nrrd.ijm"
#NRRDCONV=$VNCScripts"nrrd2raw.ijm"
NRRDCONV=$VNCScripts"nrrd2v3draw.ijm" 
ZPROJECT=$VNCScripts"z_project.ijm"
PYTHON='/misc/local/python-2.7.3/bin/python'
PREPROC=$VNCScripts"PreProcess.py"
QUAL=$VNCScripts"OverlapCoeff.py"
QUAL2=$VNCScripts"ObjPearsonCoeff.py"
LSMR=$VNCScripts"lsm2nrrdR.ijm"

echo "Job started at" `date` "on" `hostname`
SAGE_IMAGE="$grammar{sage_image}"
echo "$sage_image"

# Shepherd VNC alignment
#preproc_result=$OUTPUT"/preprocResult.nrrd"
#unregistered_raw=$OUTPUT"/unregVNC.v3draw"
#registered_pp_raw=$OUTPUT"/VNC-PP.raw"
#registered_pp_c1_nrrd=$OUTPUT"/VNC-PP_C1.nrrd"
#registered_pp_c2_nrrd=$OUTPUT"/VNC-PP_C2.nrrd"
registered_pp_sg_nrrd=$OUTPUT"/preprocResult_02.nrrd"
# Hideo output always sets reference as the first channel exported.
registered_pp_bg_nrrd=$OUTPUT"/preprocResult_01.nrrd"
registered_pp_initial_xform=$OUTPUT"/VNC-PP-initial.xform"
registered_pp_affine_xform=$OUTPUT"/VNC-PP-affine.xform"
registered_pp_warp_xform=$OUTPUT"/VNC-PP-warp.xform"
registered_pp_bgwarp_nrrd=$OUTPUT"/VNC-PP-BGwarp.nrrd"
registered_pp_warp_qual=$OUTPUT"/VNC-PP-warp_qual.csv"
registered_pp_warp_qual_temp=$OUTPUT"/VNC-PP-warp_qual.tmp"
registered_pp_sgwarp_nrrd=$OUTPUT"/VNC-PP-SGwarp.nrrd"
registered_pp_warp_png=$OUTPUT"/VNC-PP-warp.png"
#registered_pp_warp_raw=$OUTPUT"/VNC-PP-warp.raw"
registered_pp_warp_v3draw=$OUTPUT"/AlignedFlyVNC.v3draw"
registered_pp_warp_v3draw_broken=$OUTPUT"/AlignedFlyVNCBroken.v3draw"
registered_otsuna_qual=$OUTPUT"/Hideo_OBJPearsonCoeff.txt"

# Make sure the .lsm file exists
if [ -e $SUBVNC ]
then
   echo "Input file exists: "$SUBVNC
else
  echo -e "Error: image $SUBVNC does not exist"
  exit -1
fi
# Make sure that registration directory exists
#if [ ! -e $registration_dir ]
#  then
#    mkdir -p -m 755 $grammar{registration_dir}
#fi

STARTDIR=`pwd`
cd $OUTPUT
# -------------------------------------------------------------------------------------------
echo "+---------------------------------------------------------------------------------------+"
echo "| Running Otsuna preprocessing step                                                     |"
echo "| $FIJI -macro $PREPROCIMG \"$OUTPUT/,preprocResult,0,$SUBVNC,ssr,$RESX,$RESY,$GENDER\" |"
echo "+---------------------------------------------------------------------------------------+"
START=`date '+%F %T'`
$FIJI -macro $PREPROCIMG "$OUTPUT/,preprocResult,0,$SUBVNC,ssr,$RESX,$RESY,$GENDER"
STOP=`date '+%F %T'`
# -------------------------------------------------------------------------------------------
# NRRD conversion
#echo "+--------------------------------------------------------------------------------------+"
#echo "| Running raw -> NRRD conversion                                                       |"
#echo "| xvfb-run --auto-servernum --server-num=200 $FIJI -macro $LSMR $preproc_result -batch |"
#echo "+--------------------------------------------------------------------------------------+"
#START=`date '+%F %T'`
#xvfb-run --auto-servernum --server-num=200 $FIJI -macro $LSMR $preproc_result -batch
#STOP=`date '+%F %T'`
if [ ! -e $registered_pp_bg_nrrd ]
then
  echo -e "Error: Otsuna preprocessing step failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation raw_nrrd_conversion -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$FIJI" -version '1.47q' -parm imagej_macro="$LSMR"
sleep 2
# Pre-processing
#echo "+----------------------------------------------------------------------+"
#echo "| Running pre-processing                                               |"
#echo "| $PYTHON $PREPROC $registered_pp_c1_nrrd $registered_pp_c2_nrrd C 10  |"
#echo "+----------------------------------------------------------------------+"
#START=`date '+%F %T'`
#$PYTHON $PREPROC $registered_pp_c1_nrrd $registered_pp_c2_nrrd C 10
#STOP=`date '+%F %T'`
#RGB='GRB'
#echo "MIP order: $RGB"
# CMTK make initial affine
echo "+----------------------------------------------------------------------+"
echo "| Running CMTK make_initial_affine                                     |"
echo "| $CMTK/make_initial_affine --principal_axes $Tfile $registered_pp_bg_nrrd $registered_pp_initial_xform |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$CMTK/make_initial_affine --principal_axes $Tfile $registered_pp_bg_nrrd $registered_pp_initial_xform
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_initial_xform ]
then
  echo -e "Error: CMTK make initial affine failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation cmtk_initial_affine -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$CMTK/make_initial_affine" -version '2.2.6' -parm alignment_target="$Tfile"
# CMTK registration
echo "+----------------------------------------------------------------------+"
echo "| Running CMTK registration                                            |"
echo "| $CMTK/registration --initial $registered_pp_initial_xform --dofs 6,9 --auto-multi-levels 4 -o $registered_pp_affine_xform $Tfile $registered_pp_bg_nrrd |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$CMTK/registration --initial $registered_pp_initial_xform --dofs 6,9 --auto-multi-levels 4 -o $registered_pp_affine_xform $Tfile $registered_pp_bg_nrrd
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_affine_xform ]
then
  echo -e "Error: CMTK registration failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation cmtk_registration -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" - operator $USERID -program "$CMTK/registration" -version '2.2.6' -parm alignment_target="$Tfile"
# CMTK warping
echo "+----------------------------------------------------------------------+"
echo "| Running CMTK warping                                                 |"
echo "| $CMTK/warp -o $registered_pp_warp_xform --grid-spacing 80 --exploration 30 --coarsest 4 --accuracy 0.2 --refine 4 --energy-weight 1e-1 --initial $registered_pp_affine_xform $Tfile $registered_pp_bg_nrrd |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$CMTK/warp -o $registered_pp_warp_xform --grid-spacing 80 --exploration 30 --coarsest 4 --accuracy 0.2 --refine 4 --energy-weight 1e-1 --initial $registered_pp_affine_xform $Tfile $registered_pp_bg_nrrd
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_warp_xform ]
then
  echo -e "Error: CMTK warping failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation cmtk_warping -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$CMTK/warp" -version '2.2.6' -parm alignment_target="$Tfile"
# CMTK reformatting
echo "+----------------------------------------------------------------------+"
echo "| Running CMTK reformatting                                            |"
echo "| $CMTK/reformatx -o $registered_pp_bgwarp_nrrd --floating $registered_pp_bg_nrrd $Tfile $registered_pp_warp_xform |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$CMTK/reformatx -o $registered_pp_bgwarp_nrrd --floating $registered_pp_bg_nrrd $Tfile $registered_pp_warp_xform
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_bgwarp_nrrd ]
then
  echo -e "Error: CMTK reformatting failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation cmtk_reformatting -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$CMTK/reformatx" -version '2.2.6' -parm alignment_target="$Tfile"
# QC
echo "+----------------------------------------------------------------------+"
echo "| Running QC                                                           |"
echo "| $PYTHON $QUAL $registered_pp_bgwarp_nrrd $Tfile $registered_pp_warp_qual |"
echo "| $PYTHON $QUAL2 $registered_pp_bgwarp_nrrd $Tfile $registered_pp_warp_qual |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$PYTHON $QUAL $registered_pp_bgwarp_nrrd $Tfile $registered_pp_warp_qual
$PYTHON $QUAL2 $registered_pp_bgwarp_nrrd $Tfile $registered_pp_warp_qual
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_warp_qual ]
then
  echo -e "Error: quality check failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation alignment_qc -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$QUAL" -version '1.0' -parm alignment_target="$Tfile"
# -------------------------------------------------------------------------------------------                                                                                                                                                   
# CMTK reformatting
echo "+----------------------------------------------------------------------+"
echo "| Running CMTK reformatting                                            |"
echo "| $CMTK/reformatx -o $registered_pp_sgwarp_nrrd --floating $registered_pp_sg_nrrd $Tfile $registered_pp_warp_xform |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$CMTK/reformatx -o $registered_pp_sgwarp_nrrd --floating $registered_pp_sg_nrrd $Tfile $registered_pp_warp_xform
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_sgwarp_nrrd ]
then
  echo -e "Error: CMTK reformatting failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation cmtk_reformatting -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$CMTK/reformatx" -version '2.2.6' -parm alignment_target="$Tfile"
# NRRD conversion
echo "+----------------------------------------------------------------------+"
echo "| Running NRRD -> v3draw conversion                                    |"
echo "| $FIJI -macro $NRRDCONV $registered_pp_warp_v3draw         |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
$FIJI -macro $NRRDCONV $registered_pp_warp_v3draw
STOP=`date '+%F %T'`
if [ ! -e $registered_pp_warp_v3draw ]
then
  echo -e "Error: NRRD -> raw conversion failed"
  exit -1
fi
#/usr/local/pipeline/bin/add_operation -operation nrrd_raw_conversion -name "$SAGE_IMAGE" -start "$START" -stop "$STOP" -operator $USERID -program "$FIJI" -version '1.47q' -parm imagej_macro="$NRRDCONV"
sleep 2

      # Z projection
echo "+----------------------------------------------------------------------+"
echo "| Running Z projection                                                 |"
echo "| $FIJI -macro $ZPROJECT "$registered_pp_warp_v3draw $RGB $registered_pp_warp_qual_temp" |"
echo "+----------------------------------------------------------------------+"
START=`date '+%F %T'`
awk -F"," '{print $3}' $registered_pp_warp_qual | head -1 | sed 's/^  *//' >$registered_pp_warp_qual_temp
awk -F"," '{print $1 $2}' $registered_pp_warp_qual >>$registered_pp_warp_qual_temp
$FIJI -macro $ZPROJECT "$registered_pp_warp_v3draw $RGB $registered_pp_warp_qual_temp"
#/bin/rm -f $registered_pp_warp_qual_temp
STOP=`date '+%F %T'`

# -------------------------------------------------------------------------------------------                                                                                                                                                           
echo "+--------------------------------------------------------------------------------------------------------+"
echo "| Running Otsuna scoring step                                                                            |"
echo "| $FIJI -macro $POSTSCORE \"$registered_pp_bgwarp_nrrd,PostScore,$OUTPUT/,$Tfile,$POSTSCOREMASK,$GENDER\"|"
echo "+--------------------------------------------------------------------------------------------------------+"
START=`date '+%F %T'`
$FIJI -macro $POSTSCORE "$registered_pp_bgwarp_nrrd,PostScore,$OUTPUT/,$Tfile,$POSTSCOREMASK,$GENDER"
STOP=`date '+%F %T'`
if [ ! -e $registered_otsuna_qual ]
then
  echo -e "Error: Otsuna ObjPearsonCoeff score failed"
  exit -1
fi
# -------------------------------------------------------------------------------------------                                                                 
# raw to v3draw                                                                                                                                               
#echo "+----------------------------------------------------------------------+"                                                                              
#echo "| Running raw -> v3draw conversion                                     |"                                                                              
#echo "| $Vaa3D -cmd image-loader -convert $registered_pp_warp_raw $registered_pp_warp_v3draw |"                                                              
#echo "+----------------------------------------------------------------------+"                                                                            
#$Vaa3D -cmd image-loader -convert $registered_pp_warp_raw $registered_pp_warp_v3draw                                                     

# -------------------------------------------------------------------------------------------                                                                                                                                                                                                    
# ***Hack****: Saving v3draw from Fiji as a Vaa3d v3draw.  The fiji exported file is corrupted somehow.                                                                                                                                                                                          
echo "+-------------------------------------------------------------------------------------------------------------+"
echo "| Running v3draw -> v3draw conversion.  This is a hack because the Fiji v3draw writer is broken.              |"
echo "| mv $registered_pp_warp_v3draw $registered_pp_warp_v3draw_broken                                             |"
echo "| $Vaa3D -cmd image-loader -mapchannels $registered_pp_warp_v3draw_broken $registered_pp_warp_v3draw 0,1,1,0  |"
echo "+-------------------------------------------------------------------------------------------------------------+"
mv $registered_pp_warp_v3draw $registered_pp_warp_v3draw_broken
$Vaa3D -cmd image-loader -mapchannels $registered_pp_warp_v3draw_broken $registered_pp_warp_v3draw 0,1,1,0                       

if [ ! -e $registered_pp_warp_v3draw ]
then
  echo -e "Error: Final v3draw conversion failed"
  exit -1
fi
echo "+----------------------------------------------------------------------+"
echo "| Copying file to final destination                                    |"
echo "| cp -R $OUTPUT/* $FINALOUTPUT/.                                       |"
echo "+----------------------------------------------------------------------+"
cp -R $OUTPUT/* $FINALOUTPUT/.

if [[ -f "$registered_pp_warp_v3draw" ]]; then
OVERLAP_COEFF=`grep Overlap $registered_pp_warp_qual | awk -F"," '{print $1}'`
PEARSON_COEFF=`grep Pearson $registered_pp_warp_qual | awk -F"," '{print $1}'`

# Check for Hideo score file
OTSUNA_PEARSON_COEFF=`cat $registered_otsuna_qual | awk '{print $1}'`

META=${FINALOUTPUT}"/AlignedFlyVNC.properties"
echo "alignment.stack.filename=AlignedFlyVNC.v3draw" >> $META
echo "alignment.image.channels=$INPUT1_CHANNELS" >> $META
echo "alignment.image.refchan=$INPUT1_REF" >> $META
if [[ $GENDER =~ "m" ]]
then
# male fly brain
echo "alignment.space.name=Male 20x VNC Alignment Space" >> $META
else
# female fly brain
echo "alignment.space.name=Female 20x VNC Alignment Space" >> $META
fi
echo "alignment.otsuna.object.pearson.coefficient=$OTSUNA_PEARSON_COEFF" >> $META
echo "alignment.overlap.coefficient=$OVERLAP_COEFF" >> $META
echo "alignment.object.pearson.coefficient=$PEARSON_COEFF" >> $META
echo "alignment.resolution.voxels=0.52x0.52x1.00" >> $META
echo "alignment.image.size=512x1024x185" >> $META
echo "alignment.objective=20x" >> $META
echo "default=true" >> $META
fi

# Cleanup
# tar -zcf $registered_pp_warp_xform.tar.gz $registered_pp_warp_xform                                                                                                                                                                                
#x/bin/rm -rf $lsmname*-PP-*.xform $lsmname*-PP.raw $lsmname*.nrrd                                                                                                                                                                                    
#x/bin/rm -rf *-PP-*.xform *-PP.raw $registered_pp_sgwarp_nrrd $registered_pp_sg_nrrd $registered_pp_bgwarp_nrrd                                                                                                                                     
echo "Job completed at "`date`
#xtrap "rm -f $0"           
