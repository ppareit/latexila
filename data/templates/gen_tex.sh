#!/bin/sh

# remove the trailing '/' from the directories
input_dir="${1%/}"
output_dir="${2%/}"

for xml_path in $input_dir/*.xml; do
	xml_filename=`basename $xml_path`
	tex_filename="${xml_filename%.xml}.tex"
	tex_path="$output_dir/$tex_filename"

	sed -e '/^</d' -e '/^% babel package or equivalent/d' < $xml_path > $tex_path
done
