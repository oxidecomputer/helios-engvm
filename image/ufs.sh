#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

MACHINE=${MACHINE:-generic}
CONSOLE=${CONSOLE:-ttya}
VARIANT=${VARIANT:-ufs}
GROUP=${GROUP:-helios}
EXTRA=
TARNAME='helios'

ARGS=()

while getopts 'o:ENOSU' c; do
	case "$c" in
	N)
		printf 'ERROR: -N is no longer supported; use -o\n' >&2
		exit 1
		;;
	o)
		OPTE_VER="$OPTARG"
		EXTRA="-opte-$OPTE_VER"
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'opte' )
		;;
	O)
		EXTRA='-onu'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		;;
	E|S)
		EXTRA='-serdev'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'serdev' )
		;;
	U)
		#
		# Include a postboot service in the image that will attempt to
		# locate and mount the USB flash drive from which we booted at
		# "/iso".  When mounted, try to run a bash program called
		# "postboot.sh" in the root of the file system.  This allows
		# the behaviour of the ramdisk to be altered by just mounting
		# the drive and changing the contents without needed to rebuild
		# the ramdisk image.
		#
		ARGS+=( '-F' 'usb-postboot' )
		;;
	\?)
		printf 'usage: %s [-CO] [-o OPTE_VER]\n' "$0" >&2
		exit 2
		;;
	esac
done
shift $((OPTIND - 1))

cd "$TOP"

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g "$GROUP" \
    -n "$MACHINE-$CONSOLE-$VARIANT" \
    -T "$TOP/templates" \
    -F "name=$TARNAME" \
    "${ARGS[@]}"

ls -lh "$MOUNTPOINT/output/$GROUP-$MACHINE$EXTRA-$CONSOLE-$VARIANT.ufs"
