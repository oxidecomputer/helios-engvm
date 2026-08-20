#
# Copyright 2024 Oxide Computer Company
#

#
# Operate against the system libvirt instance by default, rather than the
# per-user session daemon. Override in a config/<name>.sh if needed.
#
: "${LIBVIRT_DEFAULT_URI:=qemu:///system}"
export LIBVIRT_DEFAULT_URI

VM=helios
POOL=default
INPUT_IMAGE=helios-qemu-ttya-full.raw
SIZE=30G
VCPU=2
MEM=$(( 2 * 1024 * 1024 ))
