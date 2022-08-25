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

while getopts 'O' c; do
	case "$c" in
	O)
		INSTALL=no
		ONU=yes
		NAME=helios-onu
		;;
	\?)
		printf 'usage: %s [-O]\n' "$0" >&2
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
