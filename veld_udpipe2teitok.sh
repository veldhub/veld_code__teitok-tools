#!/bin/bash

command="perl Scripts/udpipe2teitok.pl --orgfolder=/veld/input/"

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

