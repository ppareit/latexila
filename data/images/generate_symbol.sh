#!/usr/bin/env bash

# 1st parameter: directory where the symbols are stored
# 2nd parameter: name of the symbol (without the extension)
# 3rd parameter: e.g. "24x24", or "120%" to add a border, ...

cd $1
latex symbol.tex
dvipng -x 1440 -bg Transparent -T tight -z 6 -o symbol.png symbol.dvi
convert symbol.png -background Transparent -gravity Center -extent $3 $2.png
rm -f symbol.tex symbol.dvi symbol.aux symbol.log symbol.png
