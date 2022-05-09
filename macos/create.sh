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

if [[ -z $VM || -z $VCPU || -z $MEM || -z $SIZE || -z $INPUT_IMAGE ]]; then
	echo "config must define VM, VCPU, MEM, SIZE, and INPUT_IMAGE"
	exit 1
fi

VMDIR="$TOP/vm/$VM.vmwarevm"
VMX="$VMDIR/$VM.vmx"

function round_file_to_block_size {
	local filesize
	local nblocks
	local roundsize

	#
	# Determine the current file size in bytes:
	#
	if ! filesize=$(stat -f %z "$1"); then
		return 1
	fi

	#
	# Round that size up to the next block size multiple:
	#
	nblocks=$(( (filesize + 511) / 512 ))
	roundsize=$(( nblocks * 512 ))
	if (( roundsize > filesize )); then
		#
		# Append zeros to the file to make it an exact multiple of the
		# block size:
		#
		dd if=/dev/zero bs=1 count=$(( roundsize - nblocks )) >> "$1"
	fi

	echo "$nblocks"
}

#
# Check to see if the VM exists already.  We don't want to make it too easy to
# accidentally destroy your work.
#
if [[ -d "$VMDIR" ]]; then
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
XGECOS=$(id -F "$XNAME")
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

#
# Under VMware, it is ostensibly advantageous to install the Open VM Tools,
# shoddy though they are, to get time synchronisation with the host and to
# announce our IP to the management tools.
#
/usr/bin/pkg uninstall /service/network/ntpsec
/usr/bin/pkg install /system/virtualization/open-vm-tools

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
# Create the VM directory and the base VMX file:
#
mkdir -p "$TOP/vm"
mkdir "$VMDIR"
cat >"$VMX" <<EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "16"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"
hpet0.present = "TRUE"
virtualHW.productCompatibility = "hosted"
powerType.powerOff = "soft"
powerType.powerOn = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
displayName = "$VM"
guestOS = "solaris11-64"
tools.syncTime = "TRUE"
tools.upgrade.policy = "upgradeAtPowerCycle"
sound.autoDetect = "TRUE"
sound.fileName = "-1"
memsize = "$(( MEM / 1024 ))"
numvcpus = "$VCPU"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.virtualDev = "e1000"
ethernet0.linkStatePropagation.enable = "TRUE"
ethernet0.present = "TRUE"
floppy0.present = "FALSE"
keyboardAndMouseProfile = "52f51411-d518-8b24-29b0-fcdcacdc9bf0"
vvtd.enable = "TRUE"
vhv.enable = "TRUE"
bios.bootOrder = "nvme0:0"
nvme0.present = "TRUE"
nvme0:0.fileName = "root.vmdk"
nvme0:0.present = "TRUE"
nvme1.present = "TRUE"
nvme1:0.fileName = "metadata.vmdk"
nvme1:0.present = "TRUE"
serial0.present = "TRUE"
serial0.fileType = "pipe"
serial0.yieldOnMsrRead = "TRUE"
serial0.startConnected = "TRUE"
serial0.fileName = "ttya.serial"
numa.autosize.cookie = "10012"
numa.autosize.vcpu.maxPerVirtualNode = "1"
nvme0:0.redo = ""
pciBridge0.pciSlotNumber = "17"
pciBridge4.pciSlotNumber = "21"
pciBridge5.pciSlotNumber = "22"
pciBridge6.pciSlotNumber = "23"
pciBridge7.pciSlotNumber = "24"
ethernet0.pciSlotNumber = "32"
vmci0.pciSlotNumber = "33"
sata0.pciSlotNumber = "34"
nvme0.pciSlotNumber = "160"
svga.vramSize = "268435456"
vmotion.checkpointFBSize = "134217728"
vmotion.checkpointSVGAPrimarySize = "268435456"
vmotion.svga.mobMaxSize = "268435456"
vmotion.svga.graphicsMemoryKB = "262144"
monitor.phys_bits_used = "45"
cleanShutdown = "TRUE"
softPowerOff = "FALSE"
EOF

#
# Next, recreate the metadata volume cpio archive:
#
cd "$TOP/input/cpio"
find . -type f | cpio --quiet -o -O "$TOP/tmp/$VM-metadata.cpio"
cp "$TOP/tmp/$VM-metadata.cpio" "$VMDIR/metadata.img"
if ! fileblocks=$(round_file_to_block_size "$VMDIR/metadata.img"); then
	exit 1
fi
cat >> "$VMDIR/metadata.vmdk" <<EOF
# Disk DescriptorFile
version=1
encoding= #"UTF-8"
CID=fffffffe
parentCID=ffffffff
isNativeSnapshot="no"
createType="monolithicFlat"

# Extent description
RW $fileblocks FLAT "metadata.img" 0

# The Disk Data Base
#DDB
EOF
rm -f "$TOP/tmp/$VM-metadata.cpio"
cd "$TOP"

#
# Then, recreate the Helios disk from the seed image.  The target sizes is
# specified in the config file as a number of gigabytes with a G suffix; e.g.,
# 30G.  These are honest, hard working power-of-two gigabytes.
#
case "$SIZE" in
*G)
	size=$(( ${SIZE/G/} * 1024 * 1024 * 1024 ))
	;;
*M)
	size=$(( ${SIZE/M/} * 1024 * 1024 ))
	;;
*)
	echo "SIZE should end in G or M"
	exit 1
	;;
esac
#
# Rather than enlarge the image by appending zeros with dd, or finding a
# wrapper around ftruncate(2), we just create two extents and join them in the
# VMDK file.  The size of the second extent is the difference between the image
# size and the configured target size.
#
cp "$TOP/input/$INPUT_IMAGE" "$VMDIR/root0.img"
if ! r0blocks=$(round_file_to_block_size "$VMDIR/root0.img"); then
	exit 1
fi
r1size=$(( size - r0blocks * 512 ))
mkfile -n $(( r1size )) "$VMDIR/root1.img"
if ! r1blocks=$(round_file_to_block_size "$VMDIR/root1.img"); then
	exit 1
fi
cat >> "$VMDIR/root.vmdk" <<EOF
# Disk DescriptorFile
version=1
encoding= #"UTF-8"
CID=fffffffe
parentCID=ffffffff
isNativeSnapshot="no"
createType="monolithicFlat"

# Extent description
RW $r0blocks FLAT "root0.img" 0
RW $r1blocks FLAT "root1.img" 0

# The Disk Data Base
#DDB
EOF

rm -rf "$TOP/tmp"

#
# Start the VM and attach to the console so that we can see the initial boot:
#
"$TOP/macos/vmrun.sh" start "$VMX" nogui
exec "$TOP/macos/vmware-sercons/sercons" "$VMDIR/ttya.serial"
