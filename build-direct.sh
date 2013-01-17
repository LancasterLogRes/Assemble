#!/bin/bash

rootmb=128
lightboxmb=64
device=/dev/mmcblk0
separator=p
fixture=$HOME/.fixture
chrome=../Lightshow-Release/built/DirectChrome

while getopts "rldfc" opt; do
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
	\?)
		echo "Invalid option: -$OPTARG" >&2;;
		echo "Usage: ./build-direct.sh [OPTION]"
		echo "Options:"
		echo "  -r size   Make root partition <size> MB big. Default: 128"
		echo "  -l size   Make lightbox partition <size> MB big. Default: 64"
		echo "  -d device Write to block device <device>. Default: /dev/mmcblk0"
		echo "  -p string Partition separator for device. Default: p"
		echo "  -f file   Spefify fixture file. Default: $HOME/.fixture"
		echo "  -c file   Specify Chrome. Default: ../Lightshow-Release/built/DirectChrome"
	:)
		echo "Option -$OPTARG requires an argument." >&2
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

sudo apt-get install -f -y dropbear parted dosfstools e2fsprogs

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

echo "All done."
