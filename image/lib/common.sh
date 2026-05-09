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

function heliosver_setup {
	# If HELIOS_VER is not set in the environment, use the version from the
	# running system.
	if [[ -z "$HELIOS_VER" ]]; then
		HELIOS_VER=$(awk -F= '$1 == "VERSION" { print $2 }' \
		    /etc/os-release)
		HELIOS_VER+=".0"
	fi

	if [[ ! $HELIOS_VER =~ ^[0-9]\.[0-9]$ ]]; then
		printf "Invalid helios version '$HELIOS_VER'" >&2
		exit 1
	fi

	HELIOS_MVER=${HELIOS_VER%.*}
	case "$HELIOS_MVER" in
		1|2)
			PKG_PUBLISHER=helios-dev
			;;
		*)
			PKG_PUBLISHER=helios
			;;
	esac

	printf "Helios version: $HELIOS_VER ($PKG_PUBLISHER)\n"
}
