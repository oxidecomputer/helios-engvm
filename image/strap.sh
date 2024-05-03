#!/bin/bash
#
# Use the Image Builder to produce a tar file that contains an installed Helios
# system which can be used to seed an image.  The produced file should be
# something like:
#
#	/rpool/images/output/helios-dev-base.tar
#
# This tool requires "setup.sh" to have been run first.
#

#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

VARIANT=${VARIANT:-base}
WORKNAME="$VARIANT"
NAME='helios-dev'

STRAP_ARGS=()
IMAGE_SUFFIX=
OPTE=no
OPTE_VER=latest
OMICRON1=no
SSH=no
PKG=no
ONU_REPO=
ARCHIVE_ONLY=no
DEBUG=no

while getopts 'fo:s:ABDNO:PS' c; do
	case "$c" in
	A)
		ARCHIVE_ONLY=yes
		;;
	D)
		DEBUG=yes
		;;
	f)
		#
		# Use -f to request a full reset from the image builder, thus
		# effectively destroying any existing files and starting from a
		# freshly installed set of OS files.
		#
		STRAP_ARGS+=( '--fullreset' )
		;;
	O)
		NAME='helios-onu'
		ONU_REPO="$OPTARG"
		;;
	s)
		IMAGE_SUFFIX="-$OPTARG"
		;;
	N)
		printf 'ERROR: -N is no longer supported; use -o\n' >&2
		exit 1
		;;
	o)
		OPTE_VER="$OPTARG"
		NAME="helios-opte-$OPTE_VER"
		OPTE=yes
		;;
	B)
		OMICRON1=yes
		;;
	S)
		SSH=yes
		;;
	P)
		PKG=yes
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
	    [[ $version != '1.0.22' ]]; then
		printf 'install /system/zones/brand/omicron1/tools 1.0.22\n' >&2
		exit 1
	fi
fi

STEPS=()
if [[ $ARCHIVE_ONLY != yes ]]; then
	STEPS+=( '01-strap' "02-image$IMAGE_SUFFIX" )
fi
STEPS+=( '03-archive' )

for n in "${STEPS[@]}"; do
	ARGS=()
	if [[ $n == 01-strap ]]; then
		ARGS+=( "${STRAP_ARGS[@]}" )
	fi
	if [[ -n $ONU_REPO ]]; then
		WORKNAME="$VARIANT-onu"
		ARGS+=( '-N' "$VARIANT-$n-onu" '-F' "onu=$ONU_REPO" )
	fi
	if [[ $OMICRON1 == yes ]]; then
		ARGS+=( '-F' 'omicron1' )
	fi
	if [[ $OPTE == yes ]]; then
		WORKNAME="$VARIANT-opte"
		ARGS+=( '-N' "$VARIANT-$n-opte" )
		ARGS+=( '-F' "opte=$OPTE_VER" )
	fi
	if [[ $SSH == yes ]]; then
		ARGS+=( '-F' 'ssh' )
	fi
	if [[ $PKG == yes ]]; then
		ARGS+=( '-F' 'pkg' )
	fi
	if [[ $DEBUG == yes ]]; then
		ARGS+=( '-F' 'debug' )
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
		rm -f "$TOP/template/files/files.tar"
		rm -f "$TOP/template/files/gzonly.txt"
		/usr/lib/brand/omicron1/baseline \
		    -R "$MOUNTPOINT/work/helios/$WORKNAME" \
		    "$TOP/templates/files"
	fi
done

ls -lh "$MOUNTPOINT/output/$NAME-$VARIANT.tar"
