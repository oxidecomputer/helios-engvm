# Helios Image Creation

This directory contains a rough process for creating a Helios VM image for
development purposes that will run well under KVM/QEMU on a Linux workstation.

If you're interested in *running* a Helios image, a pre-built image may be
accessed from the `download.sh` script (refer [here](../README.md) for usage
instructions).

## Create an Image

This process must be run on an illumos system.

```
#
# Create the working ZFS dataset and download and build the required tools:
#
./setup.sh

#
# Create a seed tar file containing the base Helios OS files:
#
./strap.sh

#
# Customise and create a final bootable image file for QEMU/KVM:
#
MACHINE=qemu ./image.sh
```

Note that the full-size image which includes all the development tools is quite
large, and thus is not built by default.  It can be constructed by passing
`VARIANT` in the environment; e.g.,

```
./setup.sh
VARIANT=full ./strap.sh
VARIANT=full MACHINE=qemu ./image.sh
```

## Create a VM from the image

The aforementioned commands should create an output image:

```
# Check that the image was created.
ls -lh /rpool/images/output/helios-qemu-ttya-$VARIANT.raw
```

This image may be copied out of the illumos system (via a command like scp) and
used in the VM config as `INPUT_IMAGE`. For more detail, refer to the
[instructions for VM creation](../README.md#vm-creation).

## Creating the netdev ramdisk image

This is even rougher than everything else.  This is for display only; don't try
this at home!

```
./setup.sh
VARIANT=ramdisk ./strap.sh -f -N -B
MACHINE=builder ./ufs.sh -N

WEBROOT=/data/www/htdocs/builder-netdev

mkdir -p $WEBROOT/platform/i86pc/amd64
mkdir -p $WEBROOT/platform/i86pc/kernel/amd64

cd $WEBROOT &&
    tar xvfz \
    /rpool/images/output/helios-netdev-ramdisk-boot.tar.gz \
    platform/i86pc/kernel/amd64/unix

cp /rpool/images/output/helios-builder-netdev-ttya-ufs.ufs \
    $WEBROOT/platform/i86pc/amd64/boot_archive

digest -a sha1 \
    $WEBROOT/platform/i86pc/amd64/boot_archive \
    > $WEBROOT/platform/i86pc/amd64/boot_archive.hash

find $WEBROOT/ -type f -ls

#rsync --delete -Pa $WEBROOT/ catacomb:/data/media/buildomat/os-netdev/
```
