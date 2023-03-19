#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

MACHINE=${MACHINE:-generic}
SERIAL=${SERIAL:-ttya}
VARIANT=${VARIANT:-iso}

INSTALL=yes
ONU=no
NAME=helios-dev
OPTE_VER=

while getopts 'o:NO' c; do
	case "$c" in
	N)
		INSTALL=no
		;;
	o)
		OPTE_VER="$OPTARG"
		EXTRA="-netdev-$OPTE_VER"
		NAME="helios-netdev-$OPTE_VER"
		;;
	O)
		ONU=yes
		NAME=helios-onu
		;;
	\?)
		printf 'usage: %s [-o OPTE_VER] [-NO]\n' "$0" >&2
		exit 2
		;;
	esac
done

cd "$TOP"

EXTRA=
ARGS=( '-F' "name=$NAME" )
if [[ $INSTALL == yes ]]; then
	ARGS+=( '-F' 'install' )
fi
if [[ $ONU == yes ]]; then
	ARGS+=( '-F' 'onu' )
	EXTRA=onu-
fi
if [[ -n $OPTE_VER ]]; then
	ARGS+=( '-F' "opte=$OPTE_VER" )
fi

#
# Recreate the EFI system partition we include within the ISO file:
#
NAMEARGS=()
if [[ $ONU == yes ]]; then
	NAMEARGS+=( '-N' "${EXTRA}eltorito-efi" )
fi
pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "eltorito-efi" \
    -T "$TOP/templates" \
    "${NAMEARGS[@]}" \
    "${ARGS[@]}"

#
# Build the ISO itself:
#
NAMEARGS=()
if [[ $ONU == yes ]]; then
	NAMEARGS+=( '-N' "${EXTRA}$MACHINE-$SERIAL-$VARIANT" )
fi
pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "$MACHINE-$SERIAL-$VARIANT" \
    -T "$TOP/templates" \
    "${NAMEARGS[@]}" \
    "${ARGS[@]}"

ls -lh \
    "$MOUNTPOINT/output/helios-${EXTRA}eltorito-efi.pcfs" \
    "$MOUNTPOINT/output/helios-$EXTRA$MACHINE-$SERIAL-$VARIANT.iso"
