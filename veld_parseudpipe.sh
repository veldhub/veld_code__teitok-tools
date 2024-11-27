#!/bin/bash

cp /veld/input/"$in_xml_file" /veld/output/"$out_xml_file"

command="perl Scripts/parseudpipe.pl /veld/output/${out_xml_file}"

if [ "$writeback" = "true" ]; then
  command+=" --writeback"
fi

if [ -n "$model" ]; then
  command+=" --model=${model}"
fi

if [ -n "$lang" ]; then
  command+=" --lang=${lang}"
fi

if [ -n "$token" ]; then
  command+=" --token=${token}"
fi

if [ -n "$tokxp" ]; then
  command+=" --tokxp=${tokxp}"
fi

if [ -n "$sent" ]; then
  command+=" --sent=${sent}"
fi

if [ -n "$sentxp" ]; then
  command+=" --sentxp=${sentxp}"
fi

if [ -n "$atts" ]; then
  command+=" --atts=${atts}"
fi

echo "executing:"
echo "$command"
eval "$command"

