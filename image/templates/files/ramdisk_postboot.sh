#!/bin/bash

set -o errexit
set -o pipefail

mp=/iso

#
# Get the USB stick mounted.
#
mkdir -p "$mp"
mounted=$(awk -v mp="$mp" '$2 == mp { print $3 }' /etc/mnttab)
if [[ -z $mounted ]]; then
	#
	# Nothing there; try to mount!
	#
	usbdisks=$(diskinfo -H | awk '$1 == "SCSI" && /USB/ { print $2 }')
	rdev=
	for d in $usbdisks; do
		for dd in /dev/rdsk/${d}s0 /dev/rdsk/${d}p1 /dev/rdsk/${d}p0; do
			if t=$(fstyp "$dd" 2>/dev/null) &&
			    [[ $t == pcfs ]]; then
				rdev=$dd
				break
			fi
		done
	done

	if [[ -z $rdev ]]; then
		printf 'could not locate device\n' >&2
		exit 1
	fi

	bdev=$(basename "$rdev")
	dev="/dev/dsk/$bdev"
	printf 'mounting %s at %s...\n' "$dev" "$mp"
	mount -F pcfs "$dev" "$mp"
	printf 'mounted just now!\n'
else
	printf 'mounted already!\n'
fi

pb="$mp/postboot.sh"
if [[ -f "$pb" ]]; then
	printf 'executing %s...\n' "$pb"
	bash "$pb"
fi
