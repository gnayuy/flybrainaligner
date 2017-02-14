# generate 2D MIP png from 3D v3draw
# developed by Yang Yu (yuy@janelia.hhmi.org)

#
## usage: sh genMIP.sh <stack> <mip>
#
# run on the cluster
#
# sh run_configured_aligner.sh genMIP.sh 4 -d '"debug"' -o workdir 
# -c systemvars.apconf -k Toolkits -i <stack>

Vaa3D=./vaa3d
MAGICK=/usr
NETPBM=/usr

STACK=$1
WORKDIR=$2

SIGNALS=${STACK%*.v3draw}_signals.v3draw
MIP1=${SIGNALS%*.v3draw}.png

REFERENCE=${STACK%*.v3draw}_reference.v3draw
MIP2=${REFERENCE%*.v3draw}.png

MIP=${STACK%*.v3draw}.png

echo ""
echo "Vaa3D: $Vaa3D"
echo "MAGICK: $MAGICK"
echo "STACK: $STACK"
echo "MIP: $MIP"
echo ""

TEMPOUT1=${WORKDIR}/mip.tif
TEMPOUT2=${WORKDIR}/mipContrastEnhanced.tif
TEMPOUT3=${MIP1%*.png}-0.png
TEMPOUT4=${MIP1%*.png}-1.png
TEMPOUT5=${MIP1%*.png}-2.png
TEMPOUT6=${MIP2%*.png}_negated.png

TEMPOUT7=${MIP1%*.png}_mipr0.png
TEMPOUT8=${MIP1%*.png}_mipr1.png
TEMPOUT9=${MIP1%*.png}_mipr2.png
TEMPOUT10=${MIP2%*.png}_bc.png

# regenerate signal channels
$Vaa3D -x ireg -f splitColorChannels -i $STACK

CH1=${STACK%*.v3draw}_c0.v3draw
CH2=${STACK%*.v3draw}_c1.v3draw
CH3=${STACK%*.v3draw}_c2.v3draw
CH4=${STACK%*.v3draw}_c3.v3draw

$Vaa3D -x ireg -f mergeColorChannels -i $CH1 $CH2 $CH3 -o $SIGNALS

#
## signals
#
# get MIP from 3D stack
#$Vaa3D -x ireg -f zmip -i $SIGNALS -o $TEMPOUT1

# enhance contrast
$Vaa3D -x ireg -f iContrastEnhancer -i $TEMPOUT1 -o $TEMPOUT2

# convert tiff to png
$MAGICK/bin/convert -flip $TEMPOUT1 $MIP1

#
## reference
#
# get MIP from 3D stack
$Vaa3D -x ireg -f zmip -i $CH4 -o $TEMPOUT1

# enhance contrast
$Vaa3D -x ireg -f iContrastEnhancer -i $TEMPOUT1 -o $TEMPOUT2

# convert tiff to png
$MAGICK/bin/convert -flip $TEMPOUT1 $MIP2

#
## combine
#

$MAGICK/bin/convert $MIP1 -channel RGB -separate $MIP1
#$MAGICK/bin/convert -brightness-contrast -45x-55 -negate $MIP2 $TEMPOUT6
#$MAGICK/bin/convert $TEMPOUT3 $TEMPOUT4 $TEMPOUT5 $TEMPOUT6 -channel RGBA -combine $MIP

$MAGICK/bin/convert -brightness-contrast -45x-55 $MIP2 $TEMPOUT10
$MAGICK/bin/convert $TEMPOUT3 $TEMPOUT10 -compose lighten -composite $TEMPOUT7
$MAGICK/bin/convert $TEMPOUT4 $TEMPOUT10 -compose lighten -composite $TEMPOUT8
$MAGICK/bin/convert $TEMPOUT5 $TEMPOUT10 -compose lighten -composite $TEMPOUT9
$MAGICK/bin/convert $TEMPOUT7 $TEMPOUT8 $TEMPOUT9 -channel RGB -combine $MIP

#
## rm temporary files and copy the result to the right place
# 
rm $TEMPOUT1 $TEMPOUT2 $TEMPOUT3 $TEMPOUT4 $TEMPOUT5 $TEMPOUT6 $TEMPOUT7 $TEMPOUT8 $TEMPOUT9 $TEMPOUT10

