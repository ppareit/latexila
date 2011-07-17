#!/bin/sh

itstool -o help.pot C/*.page

for po_file in *.po; do
	msgmerge --update --quiet --backup=none $po_file help.pot
done
