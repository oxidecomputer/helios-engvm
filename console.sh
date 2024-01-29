#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

if [[ "$(uname)" == Darwin ]]; then
	exec "$TOP/macos/console.sh" "$@"
fi

. "$TOP/config/defaults.sh"
if [[ -n $1 ]]; then
	if ! . "$TOP/config/$1.sh"; then
		echo "failed to source configuration"
		exit 1
	fi
fi

exec virsh start --console "$VM"
