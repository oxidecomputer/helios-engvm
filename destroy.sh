#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

VM=helios
POOL=default
TOP=$(cd "$(dirname "$0")" && pwd)

#
# First, destroy the existing VM and volumes:
#
virsh destroy "$VM" || true
virsh undefine "$VM" || true
virsh vol-delete --pool "$POOL" --vol "$VM.qcow2" || true
virsh vol-delete --pool "$POOL" --vol "$VM-metadata.cpio" || true
