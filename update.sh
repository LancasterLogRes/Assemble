#!/bin/bash

echo "Building projects..."
OWD="$PWD"
for p in Lightbox-Release Lightshow-Release; do
	cd "../$p"
	if ! make -j4 2>/tmp/make-out; then
		cat /tmp/make-out
		echo "Error building. Stop."
		exit 1
	fi
	cd "$OWD"
done

ssh root@192.168.69.2 "\
	echo Mounting read/write...; \
	mount -o remount,rw /lightbox; \
	echo Stopping Chrome...; \
	mv -f /lightbox/Chrome /lightbox/Chrome.old; \
	echo Uploading Chrome...;"

ssh root@192.168.69.2 "cat > /lightbox/Chrome.new" < ../Lightshow-Release/built/DirectChrome

ssh root@192.168.69.2 "\
	echo Starting Chrome...; \
	mv /lightbox/Chrome.new /lightbox/Chrome; \
	chmod +x /lightbox/Chrome; \
	echo Mounting read-only...; \
	mount -o remount,ro /lightbox; \
	echo Done."


