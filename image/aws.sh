#!/bin/bash

#
# Produce a raw disk image suitable for use with AWS, based on a seed tar file
# and some set of additional customisations (e.g., adding a metadata agent or
# additional OS packages).  Will output an uncompressed raw disk image at,
# e.g.,
#
#	/rpool/images/output/helios-aws-vga-base.raw
#
# This tool requires "setup.sh" and "strap.sh" to have been run first.
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

VARIANT=${VARIANT:-base}

cd "$TOP"

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "aws-vga-$VARIANT" \
    -T "$TOP/templates"

ls -lh "$MOUNTPOINT/output/helios-aws-vga-$VARIANT.raw"
