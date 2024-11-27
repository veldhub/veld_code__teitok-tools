#!/bin/bash

cp /veld/input/"$in_xml_file" /veld/output/"$out_xml_file"

if [ "$enumerate" = "true" ]; then
  enumerate_flag="--enumerate"
else
  enumerate_flag=""
fi

perl Scripts/xmltokenize.pl \
  --filename=/veld/output/"$out_xml_file" \
  --textnode="$textnode" \
  --tok="$tok" \
  "$enumerate_flag" \
  --segment="$segment"

# TODO: add option, once upstream bug is fixed
  #--exclude="$exclude" \

