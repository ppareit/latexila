#!/usr/bin/env bash

xgettext -k_ -kN_ -d latexila -s -o po/sources.pot src/*.vala
xgettext -o po/glade.pot --language=Glade --omit-header src/ui/*.ui
cd po/
msgcat -o latexila.pot --use-first sources.pot glade.pot
rm sources.pot glade.pot
