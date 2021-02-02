This directory contains a rough process for creating a Helios VM image for
development purposes that will run well under KVM/QEMU on a Linux workstation.

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
./qemu.sh
```

Note that the full-size image which includes all the development tools is quite
large, and thus is not built by default.  It can be constructed by passing
`VARIANT` in the environment; e.g.,

```
./setup.sh
VARIANT=full ./strap.sh
VARIANT=full ./qemu.sh
```
