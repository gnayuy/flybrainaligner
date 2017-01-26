qsub -A flylight -pe batch 16 -l sandy=true -j y -b y -cwd -V '/nrs/scicompsoft/yuy/flylight/stitchCmd.sh < /nrs/scicompsoft/yuy/flylight/20160318_24_40X/A2_ZB2_T3/A2_ZB2_T3.conf'
