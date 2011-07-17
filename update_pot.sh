#!/bin/sh

xgettext -k_ -kN_ -d latexila --from-code=UTF-8 -o po/sources.pot src/*.vala
xgettext -o po/glade.pot --language=Glade --omit-header src/ui/*.ui
cd po/
msgcat -o latexila.pot --use-first sources.pot glade.pot
rm sources.pot glade.pot
