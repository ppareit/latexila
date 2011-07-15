#!/usr/bin/env bash

# This script migrates the GSettings data that are stored with dconf.
# Migration: LaTeXila 2.0.x -> 2.2.x

no_path=false
if [ "$1" = "" ] || [ "$1" = "--force" ]; then
	no_path=true
fi

if $no_path; then
	# test if the dconf command exists
	which dconf > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "dconf: command not found"
		echo "Migration aborted"
		exit 1
	fi

	flag=`dconf read /apps/latexila/migration-done`

	if [ "$flag" = "true" ] && [ "$1" != "--force" ]; then
		echo "Migration already done"
		echo "Use --force to force the migration"
		exit 0
	fi

	echo "Do the migration..."
fi

path="$1"
if $no_path; then
	path="/apps/latexila/"
fi

if [ "${path%/}" = "$path" ]; then
	if [ "$path" = "/apps/latexila/migration-done" ]; then
		exit 0
	fi

	echo "Migrate key $path"
	new_path="/org/gnome${path#/apps}"

	val=`dconf read $path`
	if [ "$val" != "" ]; then
		dconf write $new_path "$val"
	fi
else
	list=`dconf list $path`
	for item in $list; do
		./$0 $path$item
	done
fi

if $no_path; then
	dconf write /apps/latexila/migration-done true
	echo "Done"
fi
