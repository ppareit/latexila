#!/bin/sh

pot_file="templates.pot"

itstool -o $pot_file -i templates.its C/*.xml

for po_file in *.po; do
	msgmerge --update --quiet --backup=none $po_file $pot_file
done
