#!/bin/bash
#
# Produce a raw disk image suitable for use with a hypervisor, based on a seed
# tar file and some set of additional customisations (e.g., adding a metadata
# agent or additional OS packages).  Will output an uncompressed raw disk image
# at, e.g.,
#
#	/rpool/images/output/helios-generic-ttya-base.raw
#
# This tool requires "setup.sh" and "strap.sh" to have been run first.
#

#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

MACHINE=${MACHINE:-generic}
CONSOLE=${CONSOLE:-ttya}
VARIANT=${VARIANT:-base}
NAME='helios-dev'

ONU=no
METADATA_AGENT=yes

while getopts 'OM' c; do
	case "$c" in
	O)
		ONU=yes
		;;
	M)
		METADATA_AGENT=no
		;;
	\?)
		printf 'usage: %s [-OM]\n' "$0" >&2
		exit 2
		;;
	esac
done

cd "$TOP"

ARGS=()
EXTRA=
if [[ $ONU == yes ]]; then
	NAME='helios-onu'
	EXTRA='onu-'
	ARGS+=( '-N' "$EXTRA$MACHINE-$CONSOLE-$VARIANT" )
	ARGS+=( '-F' 'onu' )
fi
if [[ $METADATA_AGENT == no ]]; then
	ARGS+=( '-F' 'no-metadata-agent' )
fi

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "$MACHINE-$CONSOLE-$VARIANT" \
    -T "$TOP/templates" \
    -F "name=$NAME" \
    "${ARGS[@]}"

ls -lh "$MOUNTPOINT/output/helios-$EXTRA$MACHINE-$CONSOLE-$VARIANT.raw"
