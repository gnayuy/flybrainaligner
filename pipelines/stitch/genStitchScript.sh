
port=900

for i in /nrs/scicompsoft/yuy/flylight/*/*;
do


if [[ $i =~ "CEN" ]]
then

continue

fi



ii=${i%*/*}"/"

output=$i"/"${i#${ii}}".v3draw"
config=$i"/"${i#${ii}}".conf"

#echo $i
#echo $output
#echo $config


echo $i >> $config

echo $output >> $config

port=$((port+1))

echo $port >> $config


done
