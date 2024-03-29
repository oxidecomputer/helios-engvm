#!/bin/bash
#
# Experimental tool for kicking off a buildomat job that will build the image
# for the "lab" target that needs to be unpacked on the buildomat lab
# factory.
#

#
# Copyright 2024 Oxide Computer Company
#

set -o errexit
set -o pipefail

top=$(cd "$(dirname "$0")/../.." && pwd)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

#
# Build a compressed CPIO archive with the templates and scripts we will need
# within the buildomat job:
#
(cd "$top" && find tools image -type f |
    grep -v /target/ |
    grep -v ^image/aws-wire-lengths |
    grep -v ^image/metadata-agent |
    grep -v ^image/image-builder/ |
    sort) |
    (cd "$top" && cpio -o) |
    gzip > "$tmpdir/input.cpio.gz"

ls -lh "$tmpdir/input.cpio.gz"

#
# Schedule the job and save the job ID:
#
job=$(buildomat job run --no-wait \
    --name "image-builder-$(date +%s)" \
    --script-file "$top/image/experiments/jobs/builder.sh" \
    --target helios-latest \
    --output-rule '=/out/ramdisk-builder.tar.gz' \
    --output-rule '/out/meta/*' \
    --input "image.cpio.gz=$tmpdir/input.cpio.gz")

#
# Tail the output from the job so that we can see what's going on.  This also
# has the side effect of waiting for the job to complete.
#
printf 'watching job %s ...\n' "$job"
sleep 3
if ! buildomat job tail "$job"; then
	printf 'job %s failed?\n' "$job"
	exit 1
else
	printf 'job %s complete!\n' "$job"
fi

#
# List output files from the job:
#
buildomat job outputs "$job"
