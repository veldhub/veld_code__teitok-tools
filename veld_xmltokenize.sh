#!/bin/bash

cp /veld/input/"$in_xml_file" /veld/output/"$out_xml_file"

command="perl Scripts/xmltokenize.pl --filename=/veld/output/${out_xml_file}"

if [ -n "$textnode" ]; then
  command+=" --textnode=${textnode}"
fi

if [ -n "$tok" ]; then
  command+=" --tok=${tok}"
fi

# TODO: add option, once upstream bug is fixed
#if [ -n "$exclude" ]; then
#  command+=" --exclude=${exclude}"
#fi

if [ "$enumerate" = "true" ]; then
  command+=" --enumerate"
fi

if [ -n "$segment" ]; then
  command+=" --segment=${segment}"
fi

echo "executing:"
echo "$command"
eval "$command"

