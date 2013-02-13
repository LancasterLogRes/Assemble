#!/bin/bash

rootmb=256
lightboxmb=64
device=/dev/mmcblk0
separator=AUTOMATIC
fixture=$HOME/.fixture
chrome=../Lightshow-Release/built/DirectChrome
build=1
projects="Lightbox-Release Lightshow-Release"
address=192.168.69.2
key=$HOME/.ssh/id_dsa.pub
imagesizekb=992000
image=
secure=1
writable=0
userlogin=0

function usage
{
	echo "Usage: ./assemble.sh [OPTION]"
	echo "Build the Pi's SD card. Copyright Lancaster Logic Response 2013, by Gavin Wood."
	echo "Options:"
	echo "  -r size   Make root partition <size> MB big. Default: $rootmb"
	echo "  -l size   Make lightbox partition <size> MB big. Default: $lightboxmb"
	echo "  -d device Write to block device <device>. Default: $device"
	echo "  -i file   Create image in <file>. Overrides and disables -d."
	echo "  -z size   Make image <size> KB big. Default: 992000"
	echo "  -s string Partition separator for device. Default: (auto-detect)"
	echo "  -f file   Specify fixture file. Default: $fixture"
	echo "  -c file   Specify Chrome. Default: $chrome"
	echo "  -B        Don't build projects beforehand."
	echo "  -p        Project list to build. Default '$projects'"
	echo "  -a ip     The static internet address. Default $address"
	echo "  -A        Specify that a DHCP address should be taken."
	echo "  -k file   Authorize key to login as root. Default: $key"
	echo "  -n        No root password. This is insecure!"
	echo "  -w        Mount partitions read/write."
	echo "  -u        Start a user login session, not Chrome." 
	echo "  -o        Open: same as -n -w -u. This is insecure!"
	echo "  -h        Print this message."
}

while getopts "r:l:d:f:c:a:Ap:Bk:hs:i:z:nowu" opt; do
	case $opt in
	r)
		rootmb=$OPTARG;;
	l)
		lightboxmb=$OPTARG;;
	d)
		device=$OPTARG;;
	i)
		image="$OPTARG";;
	z)
		imagesizekb=$OPTARG;;
	s)
		separator=$OPTARG;;
	f)
		fixture=$OPTARG;;
	c)
		chrome=$OPTARG;;
	a)
		address=$OPTARG;;
	p)
		projects="$OPTARG";;
	B)
		build=0;;
	k)
		key=$OPTARG;;
	A)
		address=;;
	n)
		secure=0;;
	w)
		writable=1;;
	u)
		userlogin=1;;
	o)
		secure=0
		writable=1
		userlogin=1;;
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

if [ "x$separator" == "xAUTOMATIC" ]; then
	if [ "x${device/*mmcblk*/}" == "x" ]; then
		separator=p
	elif [ "x${device/*\/[sh]d[b-f]*/}" == "x" ]; then
		separator=""
	else
		echo "Unknown device partition separator - please specify with -s option."
		exit 1
	fi
fi

boottarxz=data/boot.tar.xz
roottarxz=data/root.tar.xz
vartarxz=data/var.tar.xz

sectorsize=512

startboot=63
startroot=160650

startlightbox=$((startroot+rootmb*1024*1024/sectorsize))
startvar=$((startlightbox+lightboxmb*1024*1024/sectorsize))

if [ $build == 1 ]; then
	echo "Building projects..."
	OWD="$PWD"
	for p in $projects; do
		cd "../$p"
		if ! make -j4 2>/tmp/make-out; then
			cat /tmp/make-out
			echo "Error building. Stop."
			exit 1
		fi
		cd "$OWD"
	done
fi

if [ "x$image" != "x" ]; then
	sectors=$((imagesizekb * 1024 / sectorsize))
	datasectors=$((sectors))
	disk=${image}

	echo "Zeroing..."
	dd if=/dev/zero of=$image bs=$sectorsize count=$sectors
else
	disk=${device}
	sectors=$(sudo blockdev --getsz $device)
	datasectors=$((sectors))

	echo "Unmounting..."
	for i in 1 2 3 4 ""; do
		sudo umount $device$separator$i 2>/dev/null
	done
fi



echo "Partitioning..."
sudo parted -s -a none ${disk} unit s mklabel msdos \
	mkpart primary fat32 $((startboot)) $((startroot-1)) \
	mkpart primary ext4 $((startroot)) $((startlightbox-1)) \
	mkpart primary ext4 $((startlightbox)) $((startvar-1)) \
	mkpart primary ext4 $((startvar)) $((datasectors-1))




echo "Formatting boot..."
if [ "x$image" != "x" ]; then
	dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((startroot-startboot))
	mkfs.vfat -n boot /tmp/image.part
	sudo mount /tmp/image.part /mnt
else
	sudo mkfs.vfat -n boot ${device}${separator}1
	sudo mount ${device}${separator}1 /mnt
fi
echo "Populating boot..."
sudo tar xJf $boottarxz -C /mnt 2> /dev/null
sudo umount /mnt
if [ "x$image" != "x" ]; then
	dd if=/tmp/image.part of=$image seek=$startboot obs=$sectorsize bs=$sectorsize
	rm -f /tmp/image.part
fi



echo "Formatting root..."
if [ "x$image" != "x" ]; then
	dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((startlightbox-startroot))
	mkfs.ext4 -q -L root -F /tmp/image.part
	sudo mount /tmp/image.part /mnt
else
	sudo mkfs.ext4 -q -L root ${device}${separator}2
	sudo mount ${device}${separator}2 /mnt
fi

echo "Populating root..."
sudo tar xJf $roottarxz -C /mnt
if [ $userlogin != 1 ]; then
	sudo cp -f data/rc.local /mnt/etc
fi
if [ $writable == 1 ]; then
	sudo rm -f /tmp/fstab
	sed 's/ro 0 0/rw 0 0/' <data/fstab >/tmp/fstab
	sudo cp /tmp/fstab /mnt/etc
	sudo rm -f /tmp/fstab
else
	sudo cp data/fstab /mnt/etc
fi
sudo cp $key /mnt/root/.ssh/authorized_keys

echo "Randomizing host keys..."
sudo dropbearkey -t rsa -f /mnt/etc/dropbear/dropbear_rsa_host_key >/dev/null
sudo dropbearkey -t dss -f /mnt/etc/dropbear/dropbear_dss_host_key >/dev/null

echo "Configuring network..."
sudo rm -f /mnt/etc/udev/rules.d/70-persistent-net.rules
sudo rm -f /tmp/interfaces
cp data/interfaces /tmp
if [ "x$address" == "x" ]; then
	echo "iface eth0 inet dhcp" >> /tmp/interfaces
else
	echo "iface eth0 inet static" >> /tmp/interfaces
	echo "   address $address" >> /tmp/interfaces
	echo "   netmask 255.255.255.0" >> /tmp/interfaces
	echo "   broadcast" $(echo $address | sed s/.[0-9]*$/.255/) >> /tmp/interfaces
	ssh-keygen -f "$HOME/.ssh/known_hosts" -R $address
fi
sudo cp /tmp/interfaces /mnt/etc/network
rm -f /tmp/interfaces

if [ $secure == 1 ]; then
	echo "Randomizing root password..."
	pass=$(md5pass $(md5pass))
	echo "    (password hash is $pass)"
	sudo cat /mnt/etc/shadow | sed "s|root::|root:$pass:|" > /tmp/shadow
	sudo cp /tmp/shadow /mnt/etc/shadow
	sudo rm /tmp/shadow
fi

sudo umount /mnt
if [ "x$image" != "x" ]; then
	dd if=/tmp/image.part of=$image seek=$startroot obs=$sectorsize bs=$sectorsize
	rm -f /tmp/image.part
fi



echo "Formatting lightbox..."
if [ "x$image" != "x" ]; then
	dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((startvar-startlightbox))
	mkfs.ext4 -q -L lightbox -F /tmp/image.part
	sudo mount /tmp/image.part /mnt
else
	sudo mkfs.ext4 -q -L lightbox ${device}${separator}3
	sudo mount ${device}${separator}3 /mnt
fi
echo "Populating lightbox..."
sudo cp $fixture /mnt/fixture
sudo cp $chrome /mnt/Chrome
sudo umount /mnt
if [ "x$image" != "x" ]; then
	dd if=/tmp/image.part of=$image seek=$startlightbox obs=$sectorsize bs=$sectorsize
	rm -f /tmp/image.part
fi



echo "Formatting var..."
if [ "x$image" != "x" ]; then
	dd if=/dev/zero of=/tmp/image.part bs=$sectorsize count=$((datasectors-startvar))
	mkfs.ext4 -q -L var -F /tmp/image.part
	sudo mount /tmp/image.part /mnt
else
	sudo mkfs.ext4 -q -L var ${device}${separator}4
	sudo mount ${device}${separator}4 /mnt
fi
echo "Populating var..."
sudo tar xJf $vartarxz -C /mnt
sudo umount /mnt
if [ "x$image" != "x" ]; then
	dd if=/tmp/image.part of=$image seek=$startvar obs=$sectorsize bs=$sectorsize
	rm -f /tmp/image.part
fi



sync
echo "All done."
