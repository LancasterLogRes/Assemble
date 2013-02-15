#!/bin/bash

build=0
projects="Lightbox-Release Lightshow-Release"

function usage
{
	echo "Usage: ./update.sh [OPTION]"
	echo "Update the Pi's software. Copyright Lancaster Logic Response 2013, by Gavin Wood."
	echo "Options:"
	echo "  -r        Perform rebuild."
	echo "  -h        Print this message."
}

while getopts "rh" opt; do
	case $opt in
	r)
		build=1;;
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

if [ $build == 1 ]; then
	echo "Building projects..."
	OWD="$PWD"
	for p in $projects; do
		cd "../$p"
		make clean 1>/dev/null
		make qmake 1>/dev/null
		make -j4 1>/tmp/make-out 2>/tmp/make-err
		if [ $? != 0 ]; then
			cat /tmp/make-out /tmp/make-err
			echo "Error building. Stop."
			exit 1
		fi
		cd "$OWD"
	done
fi

ssh root@192.168.69.2 "\
	echo Mounting read/write...; \
	mount -o remount,rw /lightbox; \
	echo Stopping Chrome...; \
	mv -f /lightbox/Chrome /lightbox/Chrome.old; \
	echo Uploading Chrome...;"

ssh root@192.168.69.2 "cat > /lightbox/Chrome.new" < ../Lightshow-Release/built/DirectChrome

ssh root@192.168.69.2 "\
	echo Fixing system...; \
	[ -e /lightbox/fixture ] && mv /lightbox/fixture /lightbox/scene; \
	echo Starting Chrome...; \
	mv /lightbox/Chrome.new /lightbox/Chrome; \
	chmod +x /lightbox/Chrome; \
	echo Mounting read-only...; \
	mount -o remount,ro /lightbox; \
	echo Done."


