#!/bin/bash

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
# Check to see if the VM exists already.  We don't want to make it too easy to
# accidentally destroy your work.
#
if [[ ! -f "$VMX" ]]; then
	set +o xtrace
	echo
	echo "VM $VM does not exist yet; run ./create.sh $VM"
	echo
	exit 1
fi

if pgrep -f "sercons $VMDIR/ttya.serial" >/dev/null 2>&1; then
	echo "sercons already running for that VM?"
	exit 1
fi

if ! pgrep -f "vmware-vmx.*$VMX" >/dev/null 2>&1; then
	echo "starting VM..."
	"$TOP/macos/vmrun.sh" start "$VMX" nogui
fi

exec "$TOP/macos/vmware-sercons/sercons" "$VMDIR/ttya.serial"
