#!/bin/sh

pot_file="build_tools.pot"

itstool -o $pot_file -i build_tools.its C/build_tools.xml

for po_file in *.po; do
	msgmerge --update --quiet --backup=none $po_file $pot_file
done
