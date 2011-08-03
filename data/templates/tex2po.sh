#!/bin/sh

# How to execute this script?
# $ ./tex2po.sh < letter.tex

# Useful for translators, to translate the letter template, located in
# data/templates/C/letter.xml.

# You can write a normal .tex file for the letter. Then you run this script to
# "convert" it, so you can include it in the PO file without formatting
# headache.

# Note that in the PO file, the translation must begin with:
# msgstr ""
# "\n"

sed -e 's/\\/\\\\/g' -e 's/^\(.*\)$/"\1\\n"/'
