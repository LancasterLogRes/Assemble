#!/bin/bash

rootmb=128
lightboxmb=64
device=/dev/mmcblk0
separator=p
fixture=$HOME/.fixture
chrome=../Lightshow-Release/built/DirectChrome
build=1
projects="Lightbox-Release Lightshow-Release"

function usage
{
	echo "Usage: ./build-direct.sh [OPTION]"
	echo "Build the Pi's SD card. Copyright 2013, by Gavin Wood."
	echo "Options:"
	echo "  -r size   Make root partition <size> MB big. Default: 128"
	echo "  -l size   Make lightbox partition <size> MB big. Default: 64"
	echo "  -d device Write to block device <device>. Default: /dev/mmcblk0"
	echo "  -p string Partition separator for device. Default: p"
	echo "  -f file   Spefify fixture file. Default: $HOME/.fixture"
	echo "  -c file   Specify Chrome. Default: ../Lightshow-Release/built/DirectChrome"
	echo "  -b        Build projects beforehand."
	echo "  -n        Don't build projects beforehand. Default."
	echo "  -p        Project list to build. Default 'Lightbox-Release Lightshow-Release'"
	echo "  -h        Print this message."
}

while getopts "r:l:d:f:c:p:bnh" opt; do
	case $opt in
	r)
		rootmb=$OPTARG;;
	l)
		lightboxmb=$OPTARG;;
	d)
		device=$OPTARG;;
	p)
		separator=$OPTARG;;
	f)
		fixture=$OPTARG;;
	c)
		chrome=$OPTARG;;
	p)
		projects="$OPTARG";;
	b)
		build=1;;
	n)
		build=0;;
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

boottarxz=data/boot.tar.xz
roottarxz=data/root.tar.xz
vartarxz=data/var.tar.xz

sectorsize=512
sectors=$(sudo blockdev --getsz $device)
datasectors=$((sectors))

startboot=63
startroot=160650

startlightbox=$((startroot+rootmb*1024*1024/sectorsize))
startvar=$((startlightbox+lightboxmb*1024*1024/sectorsize))

for i in 1 2 3 4; do
	sudo umount $device$separator$i 2>/dev/null
done

echo "Building projects..."
OWD="$PWD"
for p in $projects; do
	cd "../$p"
	if [ ! make -j4 2>/tmp/make-out ]; then
		cat /tmp/make-out
		echo "Error building. Stop."
		exit 1
	fi
	cd "$OWD"
done

sudo parted -s -a none ${device} unit s mklabel msdos \
	mkpart primary fat32 $((startboot)) $((startroot-1)) \
	mkpart primary ext4 $((startroot)) $((startlightbox-1)) \
	mkpart primary ext4 $((startlightbox)) $((startvar-1)) \
	mkpart primary ext4 $((startvar)) $((datasectors-1))
#	name 1 boot \
#	name 2 root \
#	name 3 lightbox \
#	name 4 var

echo "Formatting and populating boot..."
sudo mkfs.vfat -n boot ${device}${separator}1
sudo mount ${device}${separator}1 /mnt
sudo tar xJf $boottarxz -C /mnt 2> /dev/null
sudo umount /mnt

echo "Formatting and populating root..."
sudo mkfs.ext4 -q -L root ${device}${separator}2
sudo mount ${device}${separator}2 /mnt
sudo tar xJf $roottarxz -C /mnt
sudo dropbearkey -t rsa -f /mnt/etc/dropbear/dropbear_rsa_host_key
sudo dropbearkey -t dss -f /mnt/etc/dropbear/dropbear_dss_host_key
sudo cp data/fstab data/rc.local /mnt/etc
sudo umount /mnt

echo "Formatting and populating lightbox..."
sudo mkfs.ext4 -q -L lightbox ${device}${separator}3
sudo mount ${device}${separator}3 /mnt
sudo cp $fixture /mnt/fixture
sudo cp $chrome /mnt/Chrome
sudo umount /mnt

echo "Formatting and populating var..."
sudo mkfs.ext4 -q -L var ${device}${separator}4
sudo mount ${device}${separator}4 /mnt
sudo tar xJf $vartarxz -C /mnt
sudo umount /mnt

sync
echo "All done."
