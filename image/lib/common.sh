#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

if [[ -z "$TOP" ]]; then
	printf 'ERROR: set TOP before sourcing lib/common.sh\n' >&2
	exit 1
fi

if ! . "$TOP/etc/defaults.sh"; then
	exit 1
fi
if [[ -f "$TOP/etc/config.sh" ]]; then
	if ! . "$TOP/etc/config.sh"; then
		exit 1
	fi
fi

#
# Get mountpoint based on the top-level dataset for image construction:
#
MOUNTPOINT="$(zfs get -Ho value mountpoint "$DATASET")"

function github_url {
	printf 'https://github.com/%s/%s.git' "$1" "$2"
}
