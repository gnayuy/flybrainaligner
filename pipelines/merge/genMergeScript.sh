
port=900

for i in /nrs/scicompsoft/yuy/flylight/*/*;
do

ii=${i%*/*}"/"

output=$i"/"${i#${ii}}".v3draw"
config=$i"/"${i#${ii}}".config"

for j in $i/*.lsm;
do


# jj=${j%*/*}"/"

# echo "${i#${ii}} \"/\" ${j#${jj}}";

echo $j >> $config


done

echo $output >> $config

port=$((port+1))

echo $port >> $config


done
