#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

if [[ "$(uname)" == Darwin ]]; then
	exec "$TOP/macos/create.sh" "$@"
fi

fatal() {
	echo "Fatal: $*" 1>&2
	exit 1
}

volpath() {
	pool="${1:?Missing pool name}"
	shift
	volume="${1:?Missing volume name}"
	shift
	path="$(virsh vol-list --pool "${pool}" | awk "\$1==\"${volume}\" {print \$2}" -)"
	[[ -z "${path}" ]] && fatal "No path found for $volume in pool $pool"
	echo "${path}"
}

# shellcheck disable=SC1090
. "$TOP/config/defaults.sh"
if [[ -n $1 ]]; then
    # shellcheck disable=SC1090
	if ! . "$TOP/config/$1.sh"; then
		echo "failed to source configuration"
		exit 1
	fi
fi

VOL_QCOW2="${VM}.qcow2"
VOL_METADATA="${VM}-metadata.cpio"

#
# Check to see if the VM or the root disk volume exists already.  We don't want
# to make it too easy to accidentally destroy your work.
#
if virsh desc "$VM" || virsh vol-info "${VOL_QCOW2}"; then
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
find . -type f | cpio --quiet -o -O "$TOP/tmp/${VOL_METADATA}"
# shellcheck disable=SC2153
virsh vol-create-as --pool "$POOL" --capacity 1M --format raw \
    --name "${VOL_METADATA}"
virsh vol-upload --pool "$POOL" --vol "${VOL_METADATA}" \
    --file "$TOP/tmp/${VOL_METADATA}"
rm -f "$TOP/tmp/${VOL_METADATA}"
cd "$TOP"

#
# Then, recreate the Helios disk from the seed image:
#
rm -f "$TOP/tmp/${VOL_QCOW2}"
qemu-img convert -f raw -O qcow2 "$TOP/input/$INPUT_IMAGE" \
    "$TOP/tmp/${VOL_QCOW2}"
qemu-img resize "$TOP/tmp/${VOL_QCOW2}" "$SIZE"
virsh vol-create-as --pool "$POOL" --capacity "$SIZE" --format qcow2 \
    --name "${VOL_QCOW2}"
virsh vol-upload --pool "$POOL" --vol "${VOL_QCOW2}" \
    --file "$TOP/tmp/${VOL_QCOW2}"
rm -f "$TOP/tmp/${VOL_QCOW2}"

# Then, recreate the Helios VM:
#
PATH_QCOW2="$(volpath "${POOL}" "${VOL_QCOW2}")"
PATH_METADATA="$(volpath "${POOL}" "${VOL_METADATA}")"

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
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="${PATH_QCOW2}"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="disk">
      <driver name="qemu" type="raw"/>
      <source file="${PATH_METADATA}"/>
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
