qsub -A flylight -pe batch 16 -l sandy=true -j y -b y -cwd -V '/path/mergeCmd.sh < /path/sample.config'
