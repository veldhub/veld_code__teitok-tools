#!/bin/bash

command="perl /veld/code/Scripts/udpipe2teitok.pl --tmpfolder=/tmp/ --orgfolder=/veld/input/ --outfolder=/veld/output/"

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

