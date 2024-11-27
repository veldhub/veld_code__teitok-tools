#!/bin/bash

# TODO: remove hard-wired work-around, once bug is fixed
touch udpipeDEU_001.conllu
touch udpipeDEU_001.xml
touch udpipeDEU_002.conllu
touch udpipeDEU_002.xml

perl Scripts/udpipe2teitok.pl --orgfolder=/veld/input/ --lang="$lang" --model=$model

# TODO: remove hard-wired work-around, once bug is fixed
mv udpipeDEU_001.conllu /veld/output/
mv udpipeDEU_001.xml /veld/output/
mv udpipeDEU_002.conllu /veld/output/
mv udpipeDEU_002.xml /veld/output/

