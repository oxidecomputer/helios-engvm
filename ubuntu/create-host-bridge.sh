#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

if [[ -z $1 ]]; then
    echo "Argument for ethernet interface required"
    echo "example: $0 eth0"
    exit 1
fi

IFACE="$1"

# Backup the old netplan if it exists
OLD_CFG="/etc/netplan/00-installer-config.yaml"
if [[ -f "$OLD_CFG" ]]; then
    mv $OLD_CFG $OLD_CFG.bak
fi

# Install the new netplan
NEW_CFG="/etc/netplan/00-helios-engvm.yaml"
cat >"$NEW_CFG" <<EOF
network:
  ethernets:
    $IFACE:
      dhcp4: false
  version: 2
  bridges:
      virbr1:
          dhcp4: yes
          interfaces:
              - $IFACE
          parameters:
              stp: true
EOF

# Setup a bridge device so VMs can reach the LAN
virsh net-define host-bridge.xml
virsh net-start host-bridge
virsh net-autostart host-bridge

