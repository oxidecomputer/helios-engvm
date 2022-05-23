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

DATASET=rpool/images
MOUNTPOINT="$(zfs get -Ho value mountpoint "$DATASET")"
VARIANT=${VARIANT:-base}
WORKNAME="$VARIANT"
NAME='helios-dev'
NETDEV=no

TOP=$(cd "$(dirname "$0")" && pwd)

STRAP_ARGS=()
IMAGE_SUFFIX=
OMICRON1=no

while getopts 'fs:BN' c; do
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
		;;
	B)
		OMICRON1=yes
		;;
	\?)
		printf 'usage: %s [-f]\n' "$0" >&2
		exit 2
		;;
	esac
done
shift $((OPTIND - 1))

cd "$TOP"

for n in 01-strap "02-image$IMAGE_SUFFIX" 03-archive; do
	ARGS=()
	if [[ $n == 01-strap ]]; then
		ARGS+=( "${STRAP_ARGS[@]}" )
	fi
	if [[ $NETDEV == yes ]]; then
		WORKNAME="$VARIANT-netdev"
		ARGS+=( '-N' "$VARIANT-$n-netdev" '-F' 'netdev' )
	fi
	if [[ $OMICRON1 == yes ]]; then
		ARGS+=( '-F' 'omicron1' )
	fi
	banner "$n"
	pfexec "$TOP/image-builder/target/release/image-builder" \
	    build \
	    -d "$DATASET" \
	    -g helios \
	    -n "$VARIANT-$n" \
	    -T "$TOP/templates" \
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
