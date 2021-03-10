#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")/.." && pwd)

. "$TOP/config/defaults.sh"
if [[ -n $1 ]]; then
	if ! . "$TOP/config/$1.sh"; then
		echo "failed to source configuration"
		exit 1
	fi
fi

VMDIR="$TOP/vm/$VM.vmwarevm"
VMX="$VMDIR/$VM.vmx"

#
# Check to see if the VM is currently running:
#
while pgrep -f "vmware-vmx.*$VMX" >/dev/null 2>&1; do
	echo 'stopping VM...'
	"$TOP/macos/vmrun.sh" stop "$VMX" hard
	sleep 1
done

#
# Remove the files:
#
rm -rf "$VMDIR"
