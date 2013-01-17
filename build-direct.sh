#!/bin/bash

rootmb=128
lightboxmb=64
device=/dev/mmcblk0
fixture=$HOME/.fixture
directchrome=../Lightshow-Release/built/DirectChrome

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
sudo mkfs.vfat -n boot ${device}p1
sudo mount ${device}p1 /mnt
sudo tar xJf $boottarxz -C /mnt 2> /dev/null
sudo umount /mnt

echo "Formatting and populating root..."
sudo mkfs.ext4 -q -L root ${device}p2
sudo mount ${device}p2 /mnt
sudo tar xJf $roottarxz -C /mnt
sudo umount /mnt

echo "Formatting and populating lightbox..."
sudo mkfs.ext4 -q -L lightbox ${device}p3
sudo mount ${device}p3 /mnt
sudo cp $fixture /mnt/fixture
sudo cp $directchrome /mnt/DirectChrome
sudo ln -s DirectChrome /mnt/Chrome
sudo umount /mnt

echo "Formatting and populating var..."
sudo mkfs.ext4 -q -L var ${device}p4
sudo mount ${device}p4 /mnt
sudo tar xJf $vartarxz -C /mnt
sudo umount /mnt

echo "All done."
