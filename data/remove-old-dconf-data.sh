#!/usr/bin/env bash

# This script delete the dconf data used by LaTeXila 2.0.x.
# Attention, run ./migrate-dconf-data.sh first!

# test if the dconf command exists
which dconf > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "dconf: command not found"
	echo "Delete old data aborted"
	exit 1
fi

path="$1"
if [ "$path" = "" ]; then
	path="/apps/latexila/"
fi

if [ "${path%/}" = "$path" ]; then
	echo "Remove key $path"
	dconf write $path > /dev/null 2>&1
else
	list=`dconf list $path`
	for item in $list; do
		./$0 $path$item
	done
fi
