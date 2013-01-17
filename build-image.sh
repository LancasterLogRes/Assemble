#!/bin/bash

# A bit crusty - just use build-direct instead.

rootmb=128
lightboxmb=64

roottar=$HOME/root.tar
boottar=$HOME/boot.tar
vartar=$HOME/var.tar
sectors=1984000
datasectors=$((sectors))
sectorsize=512

startboot=63
startroot=160650

startlightbox=$((startroot+rootmb*1024*1024/sectorsize))
startvar=$((startlightbox+lightboxmb*1024*1024/sectorsize))

dd if=/dev/zero of=/tmp/image bs=$sectorsize count=$sectors
parted -s -a none /tmp/image unit s mklabel msdos \
	mkpart primary fat32 $((startboot)) $((startroot-1)) \
	mkpart primary ext4 $((startroot)) $((startlightbox-1)) \
	mkpart primary ext4 $((startlightbox)) $((startvar-1)) \
	mkpart primary ext4 $((startvar)) $((datasectors-1))
#	name 1 boot \
#	name 2 root \
#	name 3 lightbox \
#	name 4 var

echo "Formatting and populating boot..."
dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((startroot-startboot))
mkfs.vfat -n boot /tmp/image.part
sudo mount /tmp/image.part /mnt
sudo tar x -C /mnt -f $boottar
sudo umount /mnt
dd if=/tmp/image.part of=/tmp/image seek=$startboot obs=$sectorsize bs=$sectorsize
rm -f /rmp/image.part

echo "Formatting and populating root..."
dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((startlightbox-startroot))
mkfs.ext4 -L root -F /tmp/image.part
sudo mount /tmp/image.part /mnt
sudo tar x -C /mnt -f $roottar
sudo dropbearkey -t rsa -f /mnt/etc/dropbear/dropbear_rsa_host_key
sudo dropbearkey -t dss -f /mnt/etc/dropbear/dropbear_dss_host_key
sudo umount /mnt
dd if=/tmp/image.part of=/tmp/image seek=$startroot obs=$sectorsize bs=$sectorsize
rm -f /rmp/image.part

echo "Formatting lightbox..."
dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((startvar-startlightbox))
mkfs.ext4 -L lightbox -F /tmp/image.part
dd if=/tmp/image.part of=/tmp/image seek=$startlightbox obs=$sectorsize bs=$sectorsize
rm -f /rmp/image.part

echo "Formatting and populating var..."
dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((datasectors-startvar))
mkfs.ext4 -L var -F /tmp/image.part
sudo mount /tmp/image.part /mnt
sudo tar x -C /mnt -f $vartar
sudo umount /mnt
dd if=/tmp/image.part of=/tmp/image seek=$startvar obs=$sectorsize bs=$sectorsize
rm -f /tmp/image.part

mv /tmp/image $1
