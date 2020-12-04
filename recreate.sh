#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

VM=helios
POOL=default
SIZE=20G
VCPU=2
MEM=$(( 2 * 1024 * 1024 ))
TOP=$(cd "$(dirname "$0")" && pwd)

#
# Clear out and recreate the temporary directory:
#
cd "$TOP"
rm -rf "$TOP/tmp"
mkdir "$TOP/tmp"

#
# First, destroy the existing VM and volumes:
#
virsh destroy "$VM" || true
virsh undefine "$VM" || true
virsh vol-delete --pool "$POOL" --vol "$VM.qcow2" || true
virsh vol-delete --pool "$POOL" --vol "$VM-metadata.cpio" || true

#
# Next, recreate the metadata volume cpio archive from the proto area:
#
cd "$TOP/input/cpio"
find . -type f | cpio --quiet -o -O "$TOP/tmp/$VM-metadata.cpio"
virsh vol-create-as --pool "$POOL" --capacity 1M --format raw \
    --name "$VM-metadata.cpio"
virsh vol-upload --pool "$POOL" --vol "$VM-metadata.cpio" \
    --file "$TOP/tmp/$VM-metadata.cpio"
rm -f "$TOP/tmp/$VM-metadata.cpio"
cd "$TOP"

#
# Then, recreate the Helios disk from the seed image:
#
rm -f "$TOP/tmp/$VM.qcow2"
qemu-img convert -f raw -O qcow2 "$TOP/input/qemu.raw" "$TOP/tmp/$VM.qcow2"
qemu-img resize "$TOP/tmp/$VM.qcow2" "$SIZE"
virsh vol-create-as --pool "$POOL" --capacity "$SIZE" --format qcow2 \
    --name "$VM.qcow2"
virsh vol-upload --pool "$POOL" --vol "$VM.qcow2" \
    --file "$TOP/tmp/$VM.qcow2"
rm -f "$TOP/tmp/$VM.qcow2"

#
# Then, recreate the Helios VM:
#
cat > "$TOP/tmp/$VM.xml" <<EOF
<domain type="kvm">
  <name>helios</name>
  <memory>$MEM</memory>
  <currentMemory>$MEM</currentMemory>
  <vcpu>$VCPU</vcpu>
  <os>
    <type arch="x86_64" machine="pc-i440fx-focal">hvm</type>
    <boot dev="hd"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state="off"/>
  </features>
  <cpu mode="host-model"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="yes"/>
  </clock>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="/var/lib/libvirt/images/$VM.qcow2"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="disk">
      <driver name="qemu" type="raw"/>
      <source file="/var/lib/libvirt/images/$VM-metadata.cpio"/>
      <target dev="vdb" bus="virtio"/>
    </disk>
    <interface type="network">
      <source network="default"/>
      <model type="virtio"/>
    </interface>
    <serial type="pty"/>
  </devices>
</domain>
EOF
virsh define --file "$TOP/tmp/$VM.xml"

rm -rf "$TOP/tmp"

#
# Start the VM and attach to the console so that we can see the initial boot:
#
exec virsh start --console "$VM"
