#!/bin/bash

#
# SSH into a running virsh instance, referenced by VM name.
#

set -eou pipefail

TOP=$(cd "$(dirname "$0")" && pwd)

. "$TOP/config/defaults.sh"
if [[ "$#" -ge 1 ]]; then
  if ! . "$TOP/config/$1.sh"; then
    echo "failed to source configuration"
    exit 1
  fi
fi

USER=${USER:-$(id -un)}
IP=$(virsh domifaddr "$VM" | # Get network interfaces
               sed -n '3p' | # Jump to the third line (first two are headers)
        awk '{ print $4 }' | # Extract the fourth column (IP Address)
     awk -F/ '{ print $1 }') # IP address is written in slash notation.

ssh -A "${USER}@${IP}"
