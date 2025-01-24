#!/bin/bash

# TODO: remove hard-wired work-around, once bug is fixed
touch udpipeDEU_001.conllu
touch udpipeDEU_001.xml
touch udpipeDEU_002.conllu
touch udpipeDEU_002.xml

command="perl /veld/code/Scripts/udpipe2teitok.pl --orgfolder=/veld/input/"

if [ -n "$lang" ]; then
  command+=" --lang=${lang}"
fi

if [ -n "$model" ]; then
  command+=" --model=${model}"
fi

if [ "$mixed" = "true" ]; then
  command+=" --mixed"
fi

echo "executing:"
echo "$command"
eval "$command"

# TODO: remove hard-wired work-around, once bug is fixed
mv udpipeDEU_001.conllu /veld/output/
mv udpipeDEU_001.xml /veld/output/
mv udpipeDEU_002.conllu /veld/output/
mv udpipeDEU_002.xml /veld/output/

