#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

DATASET=rpool/images
MOUNTPOINT="$(zfs get -Ho value mountpoint "$DATASET")"
MACHINE=${MACHINE:-qemu}
SERIAL=${SERIAL:-ttya}
VARIANT=${VARIANT:-iso}

TOP=$(cd "$(dirname "$0")" && pwd)

cd "$TOP"

#
# Recreate the EFI system partition we include within the ISO file:
#
pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "eltorito-efi" \
    -T "$TOP/templates"

#
# Build the ISO itself:
#
pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "$MACHINE-$SERIAL-$VARIANT" \
    -T "$TOP/templates"

ls -lh \
    "$MOUNTPOINT/output/helios-eltorito-efi.pcfs" \
    "$MOUNTPOINT/output/helios-$MACHINE-$SERIAL-$VARIANT.iso"
