#!/bin/bash

#
# Produce a raw disk image suitable for use with QEMU/KVM/libvirt, based on a
# seed tar file and some set of additional customisations (e.g., adding a
# metadata agent or additional OS packages).  Will output an uncompressed raw
# disk image at, e.g.,
#
#	/rpool/images/output/helios-qemu-ttya-base.raw
#
# This tool requires "setup.sh" and "strap.sh" to have been run first.
#

set -o xtrace
set -o pipefail
set -o errexit

DATASET=rpool/images
MOUNTPOINT="$(zfs get -Ho value mountpoint "$DATASET")"
VARIANT=${VARIANT:-base}

TOP=$(cd "$(dirname "$0")" && pwd)

cd "$TOP"

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "qemu-ttya-$VARIANT" \
    -T "$TOP/templates"

ls -lh "$MOUNTPOINT/output/helios-qemu-ttya-$VARIANT.raw"
