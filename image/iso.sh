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
SERIAL=${SERIAL:-ttya}
VARIANT=iso

INSTALL=yes
UFS=install
ONU=no
NAME=helios-dev
OPTE_VER=
ISO_TYPE=
CONSOLE=$SERIAL
EXTRA=
OUTNAME=install

if [[ $SERIAL == vga ]]; then
	ISO_TYPE='Framebuffer Installer'
	CONSOLE=text
else
	ISO_TYPE="Serial ($SERIAL) Installer"
fi

while getopts 'o:NO' c; do
	case "$c" in
	N)
		INSTALL=no
		UFS=generic
		OUTNAME=$MACHINE
		;;
	o)
		OPTE_VER="$OPTARG"
		EXTRA="-opte-$OPTE_VER"
		NAME="helios-opte-$OPTE_VER"
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

ARGS=(
	'-F' "name=$NAME"
	'-F' "ufs=$UFS"
	'-F' "iso_type=$ISO_TYPE"
	'-F' "console=$CONSOLE"
)
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
if [[ $CONSOLE == tty* ]]; then
	ARGS+=( '-F' 'console_serial' )
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
NAMEARGS=( '-N' "$EXTRA$OUTNAME-$SERIAL" )
pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "$MACHINE-$VARIANT" \
    -T "$TOP/templates" \
    "${NAMEARGS[@]}" \
    "${ARGS[@]}"

ls -lh \
    "$MOUNTPOINT/output/helios-${EXTRA}eltorito-efi.pcfs" \
    "$MOUNTPOINT/output/helios-$EXTRA$OUTNAME-$SERIAL.iso"
