#!/bin/bash

build=0
doInstall=1
projects="Lightbox-Release Lightshow-Release"

function usage
{
	echo "Usage: ./update.sh [OPTION]"
	echo "Update the Pi's software. Copyright Lancaster Logic Response 2013, by Gavin Wood."
	echo "Options:"
	echo "  -b        Perform make"
	echo "  -r        Perform full rebuild."
	echo "  -o        Don't install; just do everything else (e.g. rebuild)."
	echo "  -h        Print this message."
}

while getopts "brop:h" opt; do
	case $opt in
	b)
		build=1;;
	r)
		build=2;;
	o)
		doInstall=0;;
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

case $build in
0)
	echo "Skipping build.";;
1)
	./rebuild.sh -b -p "$projects";;
2)
	./rebuild.sh -r -p "$projects";;
:)
	echo "Internal error: Unknown build option $build.";;
esac

if [ $doInstall != 0 ]; then
	ssh root@192.168.69.2 "\
		echo Mounting read/write...; \
		mount -o remount,rw /lightbox; \
		echo Stopping Chrome...; \
		mv -f /lightbox/Chrome /lightbox/Chrome.old; \
		echo Uploading Chrome...;"

	ssh root@192.168.69.2 "cat > /lightbox/Chrome.new" < ../Lightshow-Release/built/DirectChrome

	ssh root@192.168.69.2 "\
		echo Fixing system...; \
		[ -e /lightbox/fixture ] && sed s:fixture:scene:g </lightbox/fixture | sed s:output:driver:g >/lightbox/scene && rm -f /lightbox/fixture; \
		[ -e /lightbox/scene ] && sed s:driver:fixture:g </lightbox/scene >/lightbox/scene.new && mv /lightbox/scene.new /lightbox/scene; \
		echo Starting Chrome...; \
		mv /lightbox/Chrome.new /lightbox/Chrome; \
		chmod +x /lightbox/Chrome; \
		echo Mounting read-only...; \
		mount -o remount,ro /lightbox; \
		echo Done."
fi

