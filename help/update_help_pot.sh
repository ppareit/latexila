#!/bin/sh

pot_file="help.pot"

itstool -o $pot_file C/*.page

for po_file in *.po; do
	msgmerge --update --quiet --backup=none $po_file $pot_file
done
