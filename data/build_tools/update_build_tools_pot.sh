#!/bin/sh

itstool -o build_tools.pot -i build_tools.its build_tools-en.xml

for po_file in *.po; do
	msgmerge --update --quiet --backup=none $po_file build_tools.pot
done
