# Helios Image Creation

This directory contains a rough process for creating a Helios VM image for
development purposes that will run well under KVM/QEMU on a Linux workstation,
or some other hypervisor host.

If you're interested in *running* a Helios image, a pre-built image may be
obtained using the `download.sh` script (refer [here](../README.md) for usage
instructions).

## Prerequisites

### Privilege Elevation

Your user account needs to be able to run the
[image-builder](https://github.com/illumos/image-builder) tool with elevated
privileges (e.g., as the **root** user) in order to perform certain tasks.  To
achieve this, we use [pfexec(1)](https://illumos.org/man/1/pfexec) from within
the programs that drive the image build.  Your user account should be
configured to allow elevation; e.g., by adding the **Primary Administrator**
profile:

```
# profiles frank
Basic Solaris User
All
# usermod -P 'Primary Administrator' frank
```

```
$ id
uid=1000(frank) gid=10(staff)
$ pfexec id
uid=0(root) gid=0(root)
```

**NOTE:** This means your user can now do anything as **root** merely by
prefixing it with `pfexec`.  Configuring the system for a minimal set of
required elevations instead of blanket super-user access is currently an
exercise for the reader; see [rbac(7)](https://illumos.org/man/7/rbac),
[privileges(7)](https://illumos.org/man/7/privileges),
[auths(1)](https://illumos.org/man/1/auths),
[profiles(1)](https://illumos.org/man/1/profiles),
[roles(1)](https://illumos.org/man/1/roles),
[pfexec(1)](https://illumos.org/man/1/pfexec),
[auth_attr(5)](https://illumos.org/man/5/auth_attr),
[exec_attr(5)](https://illumos.org/man/5/exec_attr),
[prof_attr(5)](https://illumos.org/man/5/prof_attr),
[user_attr(5)](https://illumos.org/man/5/user_attr), etc.

### ZFS Dataset

The image construction process requires the use of a ZFS dataset, and the
ability to create child datasets, and create and roll back to snapshots
underneath that dataset.  The top-level dataset is, by default,
**rpool/images/$LOGNAME**.  This does not exist by default, so you must create
it:

```
$ pfexec zfs create -p rpool/images/$LOGNAME
```

The default setting is provided by `etc/defaults.sh` and you can override it
by creating an appropriate `etc/config.sh`; e.g.,

```
$ echo 'DATASET=myotherpool/images' > etc/config.sh
```

If you forget to create the dataset, there will be an error message about the
fact that it does not yet exist when you try to build an image.

## Create an Image

This process must be run on an illumos system.

```
#
# Create the working ZFS dataset and download and build the required tools:
#
gmake setup

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
gmake setup
VARIANT=full ./strap.sh
VARIANT=full MACHINE=qemu ./image.sh
```

## Create a VM from the image

The aforementioned commands should create an output image:

```
# Check that the image was created.
ls -lh /rpool/$LOGNAME/images/output/helios-qemu-ttya-$VARIANT.raw
```

This image may be copied out of the illumos system (via a command like `scp`)
and used in the VM config as `INPUT_IMAGE`.  For more detail, refer to the
[instructions for VM creation](../README.md#vm-creation).
