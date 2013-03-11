#!/bin/bash

build=1
projects="Lightbox-Release Lightshow-Release"

function usage
{
	echo "Usage: ./rebuild.sh [OPTION]"
	echo "Rebuild the Pi's software. Copyright Lancaster Logic Response 2013, by Gavin Wood."
	echo "Options:"
	echo "  -b        Perform make (default)"
	echo "  -r        Perform full rebuild."
	echo "  -h        Print this message."
}

while getopts "brh" opt; do
	case $opt in
	b)
		build=1;;
	r)
		build=2;;
	p)
		projects="$OPTARG";;
	h)
		usage
		exit 0;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		usage
		exit 1;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		usage
		exit 1;;
	esac
done

if [ $build != 0 ]; then
	echo "Building projects..."
	OWD="$PWD"
	for p in $projects; do
		cd "../$p"
		if [ $build == 2 ]; then
			make clean 2>/dev/null
			make qmake 2>/dev/null
		fi
		make -j4 1>/tmp/make-out 2>/tmp/make-err
		if [ $? != 0 ]; then
			cat /tmp/make-out /tmp/make-err
			echo "Error building. Stop."
			exit 1
		fi
		cd "$OWD"
	done
fi


