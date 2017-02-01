# timing


start=`date +%s.%N`

#
for((i=0; i<100; i++))
do

echo $i;

done


end=`date +%s.%N`
runtime=$( echo "$end - $start" | bc -l )
echo "$runtime seconds"
