#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

. "$TOP/config/defaults.sh"
if [[ -n $1 ]]; then
	if ! . "$TOP/config/$1.sh"; then
		echo "failed to source configuration"
		exit 1
	fi
fi

#
# First, destroy the existing VM and volumes:
#
virsh destroy "$VM" || true
virsh undefine "$VM" || true
virsh vol-delete --pool "$POOL" --vol "$VM.qcow2" || true
virsh vol-delete --pool "$POOL" --vol "$VM-metadata.cpio" || true
