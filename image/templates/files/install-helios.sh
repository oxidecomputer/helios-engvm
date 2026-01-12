#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o errexit
set -o pipefail

BE=helios

remove_zpool=no

while getopts 'f' c; do
	case "$c" in
	f)
		remove_zpool=yes
		;;
	*)
		printf 'Usage: %s: [-f] NODENAME DISK...\n' >&2
		exit 2
		;;
	esac
done

shift $(( $OPTIND - 1 ))

nodename="$1"
shift
if [[ -z $nodename ]]; then
	printf 'specify nodename and rpool disk(s)\n' >&2
	exit 2
fi

if (( $# == 0 )) || [[ -z "$1" ]]; then
	printf 'specify nodename and rpool disk(s)\n' >&2
	exit 2
elif (( $# == 1 )); then
	pooldesc=( "$1" )
elif (( $# == 2 )); then
	pooldesc=( mirror "$1" "$2" )
elif (( $# == 3 )); then
	pooldesc=( raidz1 "$1" "$2" "$3" )
else
	printf 'too many arguments?\n' >&2
	exit 1
fi

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
		for rdsk in /dev/rdsk/*p0 /dev/rdsk/*s0 /dev/rdsk/*s1; do
			if [[ ! -e "$rdsk" ]]; then
				continue
			fi

			if ! typ=$(fstyp "$rdsk"); then
				continue
			fi

			if [[ "$typ" != 'hsfs' && "$typ" != 'pcfs' ]]; then
				continue
			fi

			while umount /iso; do
				sleep 0.1
			done

			mkdir -p /iso
			if ! mount -F "$typ" \
			    "/dev/dsk/$(basename "$rdsk")" "/iso"; then
				continue
			fi

			if [[ -f /iso/install/image.tar.gz ]]; then
				break
			fi

			umount /iso
		done
	fi

	if [[ ! -f /iso/install/image.tar.gz ]]; then
		printf 'could not locate install media\n'
		exit 1
	fi
fi

mkdir -p /altroot
mkdir -p /a

if [[ $remove_zpool == yes ]]; then
	shift
	printf 'removing rpool first...\n'
	if zpool import -f -N -R /altroot rpool; then
		zpool destroy rpool
	fi
fi

printf 'NODENAME: %s\n' "$nodename"

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
    org.opensolaris.libbe:uuid=$UUID \
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

echo "$nodename" > /a/etc/nodename

sed -i -e '/^console:/s/9600/115200/g' /a/etc/ttydefs

#
# Copy some files we customise in the ramdisk image into the installed root:
#
for f in /etc/default/init /etc/inet/chrony.conf /etc/auto_master; do
	rm -f "/a$f"
	cp "$f" "/a$f"
done

#
# Replicate whatever settings were used for the install console:
#
rm -f /a/boot/conf.d/console
for key in console os_console ttya-mode ttyb-mode; do
	val=$(/usr/lib/bootparams "$key")
	if [[ -n $val ]]; then
		printf '%s="%s"\n' "$key" "$val" >> /a/boot/conf.d/console
	fi
done

SHAD='$5$kr1VgdIt$OUiUAyZCDogH/uaxH71rMeQxvpDEY2yX.x0ZQRnmeb9' # blank
sed -i -e "/^root:/s,.*,root:$SHAD:6445::::::," /a/etc/shadow

sed -i -e '/PermitRoot/s/no/without-password/' /a/etc/ssh/sshd_config
mkdir /a/root/.ssh

zpool set bootfs=rpool/ROOT/$BE rpool

beadm activate helios
bootadm install-bootloader -M -f -P rpool -R /a
bootadm update-archive -f -R /a

zfs create -o mountpoint=/home rpool/home

set +o xtrace

printf 'should be ok to reboot now\n'
