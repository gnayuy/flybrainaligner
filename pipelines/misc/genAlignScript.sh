

# for i in /nrs/scicompsoft/yuy/registration/images/*/alignCmd.sh; do qsub -pe batch 32 -l broadwell=true -j y -b y -cwd -V $i; done
# qstat



INPUTDIR=$1
THREAD=$2
OUT=$3


echo "sh /nrs/scicompsoft/yuy/registration/brainAlignerJfrc2010Cmtk.sh $INPUTDIR $THREAD" >> $OUT
chmod 755 $OUT
