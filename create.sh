#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

if [[ "$(uname)" == Darwin ]]; then
	exec "$TOP/macos/create.sh" "$@"
fi

. "$TOP/config/defaults.sh"
if [[ -n $1 ]]; then
	if ! . "$TOP/config/$1.sh"; then
		echo "failed to source configuration"
		exit 1
	fi
fi

if [[ -z $VM || -z $POOL || -z $VCPU || -z $MEM || -z $SIZE ||
    -z $INPUT_IMAGE ]]; then
	echo "config must define VM, POOL, VCPU, MEM, SIZE, and INPUT_IMAGE"
	exit 1
fi

#
# Locate QEMU on this system, in case it is not in /usr/bin.
#
QEMU=/usr/bin/qemu-system-x86_64
if [[ ! -x $QEMU ]]; then
	#
	# Try asking the shell:
	#
	if ! QEMU=$(command -v qemu-system-x86_64) || [[ ! -x $QEMU ]]; then
		echo "could not locate QEMU"
		exit 1
	fi
fi

#
# The VM we create will have two volumes: the root disk created from the OS
# image, and a small metadata disk that we create here.
#
VOL_QCOW2="$VM.qcow2"
VOL_METADATA="$VM-metadata.cpio"

#
# Check to make sure the configured storage pool exists.
#
if ! virsh pool-info "$POOL" >/dev/null; then
	#
	# We assume that an error means the pool does not exist.  Distributions
	# seem to differ on the set of conditions under which they will
	# pre-create the default pool, and on the location at which they might
	# create it.  If the pool name is "default", to ease onboarding we will
	# try to create it where Ubuntu generally does.
	#
	if [[ $POOL != default ]]; then
		echo "libvirt pool $POOL needs to be created before use"
		exit 1
	fi

	#
	# Note that creating this definition does not seem to create the
	# directory.  This directory appears to be created as part of package
	# installation on at least Ubuntu systems, but other distributions may
	# not ship with one.
	#
	defpath=/var/lib/libvirt/images
	echo "creating pool $POOL at path $defpath..."
	virsh pool-define /dev/stdin <<-EOF
	<pool type='dir'>
		<name>$POOL</name>
		<target>
			<path>$defpath</path>
		</target>
	</pool>
	EOF

	#
	# It is not clear what it means for a directory to be "started", but we
	# shall try all the same:
	#
	virsh pool-autostart "$POOL"
	virsh pool-start "$POOL"
fi

#
# Check to see if the VM or the disk volumes exist already.  We don't want to
# make it too easy to accidentally destroy your work.
#
if virsh desc "$VM" ||
    virsh vol-info --pool "$POOL" "$VOL_QCOW2" ||
    virsh vol-info --pool "$POOL" "$VOL_METADATA"; then
	set +o xtrace
	echo
	echo "VM $VM exists already; run ./destroy.sh if you want to recreate"
	echo
	exit 1
fi

#
# Clear out and recreate the temporary directory:
#
cd "$TOP"
rm -rf "$TOP/tmp"
mkdir "$TOP/tmp"

#
# Before we do anything else, decide if the user has an appropriate SSH key
# file available.
#
mkdir -p "$TOP/input/cpio"
if [[ ! -f "$TOP/input/cpio/authorized_keys" ]]; then
	if [[ ! -f $HOME/.ssh/authorized_keys ]]; then
		echo "you have no $HOME/.ssh/authorized_keys file"
		echo
		echo "populate $TOP/input/cpio/authorized_keys and run again"
		echo
		exit 1
	fi
	cp "$HOME/.ssh/authorized_keys" "$TOP/input/cpio/authorized_keys"
fi

#
# Produce the firstboot script that will run in the new guest to set up a basic
# user account.  We try to use the same details as the current user, which
# should ease the use of NFS and SSH if you choose to use them.
#
XID=$(id -u)
XNAME=$(id -un)
XGECOS=$(getent passwd "$XNAME" | cut -d: -f5)
cat >"$TOP/input/cpio/firstboot.sh" <<EOF
#!/bin/bash
set -o errexit
set -o pipefail
set -o xtrace
echo 'Just a moment...' >/dev/msglog
/sbin/zfs create 'rpool/home/$XNAME'
/usr/sbin/useradd -u '$XID' -g staff -c '$XGECOS' -d '/home/$XNAME' \\
    -P 'Primary Administrator' -s /bin/bash '$XNAME'
/bin/passwd -N '$XNAME'
/bin/mkdir '/home/$XNAME/.ssh'
/bin/cp /root/.ssh/authorized_keys '/home/$XNAME/.ssh/authorized_keys'
/bin/chown -R '$XNAME:staff' '/home/$XNAME'
/bin/chmod 0700 '/home/$XNAME'
/bin/sed -i \\
    -e '/^PATH=/s#\$#:/opt/ooce/bin:/opt/ooce/sbin#' \\
    /etc/default/login
/bin/ntpdig -S 0.pool.ntp.org || true
(
    echo
    echo
    banner 'oh, hello!'
    echo
    echo "You should be able to SSH to your VM:"
    echo
    ipadm show-addr -po type,addr | grep '^dhcp:' |
        sed -e 's/dhcp:/    ssh $XNAME@/' -e 's,/.*,,'
    echo
    echo
) >/dev/msglog
exit 0
EOF

#
# Set the hostname of the guest to the same name as the VM name:
#
echo "$VM" > "$TOP/input/cpio/nodename"

#
# Next, recreate the metadata volume cpio archive:
#
cd "$TOP/input/cpio"
find . -type f | cpio --quiet -o -O "$TOP/tmp/$VOL_METADATA"
virsh vol-create-as --pool "$POOL" --capacity 1M --format raw \
    --name "$VOL_METADATA"
virsh vol-upload --pool "$POOL" --vol "$VOL_METADATA" \
    --file "$TOP/tmp/$VOL_METADATA"
rm -f "$TOP/tmp/$VOL_METADATA"
if ! FILE_METADATA=$(virsh vol-path --pool "$POOL" "$VOL_METADATA"); then
	echo "could not determine path for $VOL_METADATA"
	exit 1
fi
cd "$TOP"

#
# Then, recreate the Helios disk from the seed image:
#
rm -f "$TOP/tmp/$VOL_QCOW2"
qemu-img convert -f raw -O qcow2 "$TOP/input/$INPUT_IMAGE" \
    "$TOP/tmp/$VOL_QCOW2"
qemu-img resize "$TOP/tmp/$VOL_QCOW2" "$SIZE"
virsh vol-create-as --pool "$POOL" --capacity "$SIZE" --format qcow2 \
    --name "$VOL_QCOW2"
virsh vol-upload --pool "$POOL" --vol "$VOL_QCOW2" \
    --file "$TOP/tmp/$VOL_QCOW2"
if ! FILE_QCOW2=$(virsh vol-path --pool "$POOL" "$VOL_QCOW2"); then
	echo "could not determine path for $VOL_QCOW2"
	exit 1
fi
rm -f "$TOP/tmp/$VOL_QCOW2"

#
# Then, recreate the Helios VM:
#
cat > "$TOP/tmp/$VM.xml" <<EOF
<domain type="kvm">
  <name>$VM</name>
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
    <emulator>$QEMU</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="$FILE_QCOW2"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="disk">
      <driver name="qemu" type="raw"/>
      <source file="$FILE_METADATA"/>
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
