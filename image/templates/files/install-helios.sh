#!/bin/bash

set -o errexit
set -o pipefail

BE=helios

#
# First, locate the install media from which we will collect the install image.
#
if [[ ! -f /iso/install/image.tar.gz ]]; then
	if [[ -f /system/boot/install.env.sh ]]; then
		#
		# If we have booted in a network environment, we may be
		# required to get the files from the server.
		#
		printf 'using network...\n'
		. /system/boot/install.env.sh

		while umount /iso; do
			sleep 0.1
		done
		mkdir -p /iso
		mount -F tmpfs "/dev/dsk/$(basename "$rdsk")" "/iso"

		mkdir /iso/install
		curl -o /iso/install/image.tar.gz -fsSL "$URL"
		gzip -t /iso/install/image.tar.gz
	else
		printf 'locating ISO...\n'
		for rdsk in /dev/rdsk/*p0; do
			if [[ ! -e "$rdsk" ]]; then
				continue
			fi

			if ! typ=$(fstyp "$rdsk"); then
				continue
			fi

			if [[ "$typ" != 'hsfs' ]]; then
				continue
			fi

			mkdir -p /iso
			if ! mount -F hsfs \
			    "/dev/dsk/$(basename "$rdsk")" "/iso"; then
				continue
			fi
		done
	fi

	if [[ ! -f /iso/install/image.tar.gz ]]; then
		printf 'could not locate install media\n'
		exit 1
	fi
fi

mkdir -p /altroot
mkdir -p /a

if [[ $1 == -f ]]; then
	shift
	printf 'removing rpool first...\n'
	if zpool import -f -N -R /altroot rpool; then
		zpool destroy rpool
	fi
fi

NODENAME=$1
DISK1=$2
DISK2=$3
if [[ -z $DISK1 || -z $NODENAME ]]; then
	printf 'specify nodename and rpool disk(s)\n'
	exit 1
fi
if [[ -n $4 ]]; then
	printf 'too many arguments?\n'
	exit 1
fi

printf 'NODENAME: %s\n' "$NODENAME"

if [[ -n $DISK2 ]]; then
	pooldesc=( mirror "$DISK1" "$DISK2" )
else
	pooldesc=( "$DISK1" )
fi
printf 'POOL LAYOUT: %s\n' "${pooldesc[*]}"

set -o xtrace

zpool create -f -O compression=on -R /altroot -B rpool "${pooldesc[@]}"

#
# Create BE
#
zfs create -o canmount=off -o mountpoint=legacy rpool/ROOT
zfs create -o canmount=noauto -o mountpoint=legacy rpool/ROOT/$BE
mount -F zfs rpool/ROOT/$BE /a

UUID=$(uuidgen)
for v in \
    org.opensolaris.libbe:uuidorg.opensolaris.libbe:uuid=$UUID \
    org.opensolaris.libbe:policy=static; do
	zfs set $v rpool/ROOT/$BE
done

/usr/sbin/tar xzeEp@/f /iso/install/image.tar.gz -C /a
/usr/sbin/devfsadm -r /a

rm -rf /a/dev/dsk/*
rm -rf /a/dev/rdsk/*
rm -rf /a/dev/cfg/*
rm -rf /a/dev/usb/*

rm -f /a/dev/msglog
ln -s ../devices/pseudo/sysmsg@0:msglog /a/dev/msglog

rm -f /a/etc/svc/profile/generic.xml
ln -s generic_limited_net.xml /a/etc/svc/profile/generic.xml

rm -f /a/etc/svc/profile/inetd_services.xml
ln -s inetd_generic.xml /a/etc/svc/profile/inetd_services.xml

rm -f /a/etc/svc/profile/platform.xml
ln -s platform_none.xml /a/etc/svc/profile/platform.xml

rm -f /a/etc/svc/profile/name_service.xml
ln -s ns_dns.xml /a/etc/svc/profile/name_service.xml

rm -f /a/etc/nsswitch.conf
cp /a/etc/nsswitch.dns /a/etc/nsswitch.conf

echo "$NODENAME" > /a/etc/nodename

sed -i -e '/^console:/s/9600/115200/g' /a/etc/ttydefs

SHAD='$5$kr1VgdIt$OUiUAyZCDogH/uaxH71rMeQxvpDEY2yX.x0ZQRnmeb9' # blank
sed -i -e "/^root:/s,.*,root:$SHAD:6445::::::," /a/etc/shadow

sed -i -e '/PermitRoot/s/no/without-password/' /a/etc/ssh/sshd_config
mkdir /a/root/.ssh

zpool set bootfs=rpool/ROOT/$BE rpool

beadm activate helios
bootadm install-bootloader -M -f -P rpool -R /a
bootadm update-archive -f -R /a

#
# XXX the way the boot environment is mounted is currently allowing files to be
# created under /a/rpool/* which then prevents /rpool from being mounted on
# first boot.
#
#rm -f /a/rpool/boot/menu.lst
#rmdir /a/rpool/boot

set +o xtrace

printf 'should be ok to reboot now\n'
