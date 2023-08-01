#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

cd "$TOP"

VARIANT=base ./strap.sh -f
VARIANT=ramdisk ./strap.sh -f

UFS=install
MACHINE=$UFS ./ufs.sh

MACHINE=${MACHINE:-generic}
SERIALS=${SERIALS:-vga ttya ttyb}

UFS=install
NAME=helios-dev
OUTNAME=install

function redo_args {
	SERIAL=$1

	ISO_TYPE=
	CONSOLE=$SERIAL
	if [[ $SERIAL == vga ]]; then
		ISO_TYPE='Framebuffer Installer'
		CONSOLE=text
	else
		ISO_TYPE="Serial ($SERIAL) Installer"
	fi

	ARGS=(
		'-F' "name=$NAME"
		'-F' "ufs=$UFS"
		'-F' "iso_type=$ISO_TYPE"
		'-F' "console=$CONSOLE"
		'-F' 'install'
	)

	if [[ $CONSOLE == tty* ]]; then
		ARGS+=( '-F' 'console_serial' )
	fi
}

#
# Recreate the EFI system partition we include within the ISO file:
#
redo_args vga
pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "eltorito-efi" \
    -T "$TOP/templates" \
    "${ARGS[@]}"

#
# Build the ISO itself:
#
for s in $SERIALS; do
	banner "$s"

	NAMEARGS=( '-N' "$OUTNAME-$s" )

	redo_args "$s"
	pfexec "$TOP/image-builder/target/release/image-builder" \
	    build \
	    -d "$DATASET" \
	    -g helios \
	    -n "$MACHINE-iso" \
	    -T "$TOP/templates" \
	    -N "$OUTNAME-$s" \
	    "${ARGS[@]}"
done

for s in $SERIALS; do
	ls -lh "$MOUNTPOINT/output/helios-install-$s.iso"
done
