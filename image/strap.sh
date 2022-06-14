#!/bin/bash

#
# Use the Image Builder to produce a tar file that contains an installed Helios
# system which can be used to seed an image.  The produced file should be
# something like:
#
#	/rpool/images/output/helios-dev-base.tar.gz
#
# This tool requires "setup.sh" to have been run first.
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

VARIANT=${VARIANT:-base}
WORKNAME="$VARIANT"
NAME='helios-dev'
NETDEV=no
COFFEE=no

STRAP_ARGS=()
IMAGE_SUFFIX=
OPTE=no
OMICRON1=no
SSH=no

while getopts 'fs:BCN' c; do
	case "$c" in
	f)
		#
		# Use -f to request a full reset from the image builder, thus
		# effectively destroying any existing files and starting from a
		# freshly installed set of OS files.
		#
		STRAP_ARGS+=( '--fullreset' )
		;;
	s)
		IMAGE_SUFFIX="-$OPTARG"
		;;
	N)
		NAME='helios-netdev'
		NETDEV=yes
		OPTE=yes
		;;
	B)
		OMICRON1=yes
		;;
	C)
		NAME='helios-coffee'
		COFFEE=yes
		OPTE=yes
		SSH=yes
		;;
	\?)
		printf 'usage: %s [-f]\n' "$0" >&2
		exit 2
		;;
	esac
done
shift $((OPTIND - 1))

cd "$TOP"

if [[ $OMICRON1 == yes ]]; then
	#
	# If we need to create an omicron brand baseline, make sure the right
	# package is installed:
	#
	if ! version=$(pkg info /system/zones/brand/omicron1/tools |
	    awk '$1 == "Version:" { print $2 }') ||
	    [[ $version != '1.0.5' ]]; then
		printf 'install /system/zones/brand/omicron1/tools 1.0.5\n' >&2
		exit 1
	fi
fi

for n in 01-strap "02-image$IMAGE_SUFFIX" 03-archive; do
	ARGS=()
	if [[ $n == 01-strap ]]; then
		ARGS+=( "${STRAP_ARGS[@]}" )
	fi
	if [[ $NETDEV == yes ]]; then
		WORKNAME="$VARIANT-netdev"
		ARGS+=( '-N' "$VARIANT-$n-netdev" '-F' 'netdev' )
	fi
	if [[ $COFFEE == yes ]]; then
		WORKNAME="$VARIANT-coffee"
		ARGS+=( '-N' "$VARIANT-$n-coffee" '-F' 'coffee' )
	fi
	if [[ $OMICRON1 == yes ]]; then
		ARGS+=( '-F' 'omicron1' )
	fi
	if [[ $OPTE == yes ]]; then
		ARGS+=( '-F' 'opte' )
	fi
	if [[ $SSH == yes ]]; then
		ARGS+=( '-F' 'ssh' )
	fi
	banner "$n"
	pfexec "$TOP/image-builder/target/release/image-builder" \
	    build \
	    -d "$DATASET" \
	    -g helios \
	    -n "$VARIANT-$n" \
	    -T "$TOP/templates" \
	    -F "name=$NAME" \
	    "${ARGS[@]}"

	if [[ $OMICRON1 == yes && $n == 02-image* ]]; then
		#
		# After we add the extra packages, create the zone baseline:
		#
		banner baseline
		rm -f "$TOP/template/files/files.tar.gz"
		rm -f "$TOP/template/files/gzonly.txt"
		/usr/lib/brand/omicron1/baseline \
		    -R "$MOUNTPOINT/work/helios/$WORKNAME" \
		    "$TOP/templates/files"
	fi
done

ls -lh "$MOUNTPOINT/output/$NAME-$VARIANT.tar.gz"
