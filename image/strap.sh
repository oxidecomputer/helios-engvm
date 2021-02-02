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

TOP=$(cd "$(dirname "$0")" && pwd)

cd "$TOP"

for n in 01-strap 02-image 03-archive; do
	banner "$n"
	pfexec "$TOP/image-builder/target/release/image-builder" \
	    build \
	    -d "$DATASET" \
	    -g helios \
	    -n "$VARIANT-$n" \
	    -T "$TOP/templates"
done

ls -lh "$MOUNTPOINT/output/helios-dev-$VARIANT.tar.gz"
