#!/bin/bash
#
# stitching script 12/06/2016
#

read INPUTDIR
read OUTPUT
read DISPLAY_PORT
echo "Running on "`hostname`
echo "Finding a port for Xvfb, starting at $DISPLAY_PORT..."
PORT=$DISPLAY_PORT COUNTER=0 RETRIES=10
function cleanXvfb {
    kill $MYPID
    rm -f /tmp/.X${PORT}-lock
    rm -f /tmp/.X11-unix/X${PORT}
    echo "Cleaned up Xvfb"
}
trap cleanXvfb EXIT
while [ "$COUNTER" -lt "$RETRIES" ]; do
    while (test -f "/tmp/.X${PORT}-lock") || (test -f "/tmp/.X11-unix/X${PORT}") || (netstat -atwn | grep "^.*:${PORT}.*:\*\s*LISTEN\s*$")
        do PORT=$(( ${PORT} + 1 ))
    done
    echo "Found the first free port: $PORT"
    /usr/bin/Xvfb :${PORT} -screen 0 1x1x24 -fp /usr/share/X11/fonts/misc > Xvfb.${PORT}.log 2>&1 &
    echo "Started Xvfb on port $PORT"
    MYPID=$!
    export DISPLAY="localhost:${PORT}.0"
    sleep 3
    if kill -0 $MYPID >/dev/null 2>&1; then
        echo "Xvfb is running as $MYPID"
        break
    else
        echo "Xvfb died immediately, trying again..."
        cleanXvfb
        PORT=$(( ${PORT} + 1 ))
    fi
    COUNTER="$(( $COUNTER + 1 ))"
done

export LD_LIBRARY_PATH=/groups/jacs/jacsHosts/servers/jacs/executables/Qt-4.7.4-redhat/lib:/groups/jacs/jacsHosts/servers/jacs/executables/vaa3d-redhat/lib:$LD_LIBRARY_PATH

V3D=/groups/jacs/jacsHosts/servers/jacs-data2/executables/vaa3d-redhat/vaa3d

time $V3D -x imageStitch -f v3dstitch -i $INPUTDIR -p "#c 4 #si 0";

time $V3D -x ifusion -f iblender -i $INPUTDIR -o $OUTPUT

