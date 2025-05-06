#!/bin/bash
#
# Experimental tool for kicking off a buildomat job that will build the proto
# tar file for for the "helios-2.0-*" target, which can then be used to create
# images for different hypervisors.
#

#
# Copyright 2025 Oxide Computer Company
#

set -o errexit
set -o pipefail

do_wait=yes
quiet=no
while getopts 'qW' c; do
	case "$c" in
	q)
		quiet=yes
		;;
	W)
		do_wait=no
		;;
	*)
		printf 'Usage: %s [-qW]\n' >&2
		exit 2
		;;
	esac
done
shift $(( OPTIND - 1 ))

top=$(cd "$(dirname "$0")/../.." && pwd)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

#
# Build a compressed CPIO archive with the templates and scripts we will need
# within the buildomat job:
#
cpioargs=()
if [[ $quiet == yes ]]; then
	cpioargs+=( '-q' )
fi
(cd "$top" && find tools image -type f |
    grep -v /target/ |
    grep -v ^image/aws-wire-lengths |
    grep -v ^image/metadata-agent |
    grep -v ^image/image-builder/ |
    sort) |
    (cd "$top" && cpio -o "${cpioargs[@]}") |
    gzip > "$tmpdir/input.cpio.gz"

if [[ $quiet != yes ]]; then
	ls -lh "$tmpdir/input.cpio.gz"
fi

#
# Schedule the job and save the job ID:
#
job=$(buildomat job run --no-wait \
    --name "image-builder-full-tar-$(date +%s)" \
    --script-file "$top/image/experiments/jobs/builder_full_tar.sh" \
    --target helios-2.0 \
    --output-rule "=/out/helios-dev-full.tar.zst" \
    --output-rule '/out/meta/*' \
    --input "image.cpio.gz=$tmpdir/input.cpio.gz")

if [[ $do_wait == no ]]; then
	printf '%s\n' "$job"
	exit 0
fi

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
