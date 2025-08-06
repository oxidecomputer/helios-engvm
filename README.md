# Helios Engineering System Tools

This repository contains tools for setting up a Helios virtual or physical host
for development purposes.  It provides support for at least the following
environments:

* Linux workstation, Ubuntu 20.04.01 LTS, KVM/QEMU as managed by libvirt
* Macintosh workstation (with an Intel CPU), VMware Fusion 12

## Creating a Helios Virtual Machine

### Installing Dependencies

#### Linux

These instructions assume you are using an Ubuntu 20.04.01 LTS system and that
you have the libvirt suite installed.  The easiest way to get these tools is to
install the `virt-manager` package, which also gets you a limited GUI interface
for managing virtual machines; e.g.,

```
host ~ $ sudo apt install virt-manager
```

So that you can interact with virtual machines directly, make sure your regular
user account is a member of the `libvirt` group.

NOTE: New group memberships generally don't take effect until you log out and
log in again; to avoid needing to do that you can temporarily switch your
primary group to libvirt with `newgrp`.  You only need to do this until the
next time you log out and log in.

```
host ~ $ sudo usermod -a -G libvirt $(whoami)
host ~ $ newgrp libvirt
```

#### Macintosh

**NOTE: Helios is only built for x86 CPUs, so these instructions will only work
on a Macintosh with an Intel CPU.  Newer systems with ARM CPUs are not suitable
and will not work.**

Install VMware Fusion.  These instructions have been tested with VMware Fusion
12.1.  It should be installed in the usual place; i.e.,
`/Applications/VMware Fusion.app`.

Run the setup script that will download the `vmware-sercons` tool and build it
from source:

```
host ~ $ ./macos/setup.sh
```

You will need to have some package installed that provides `make` and `gcc`,
such as XCode or the SDK command-line utilities.

### Downloading Seed Image

To create the virtual machine, you must first obtain the seed image:

```
host ~/helios-engvm $ ./download.sh
checking hash on existing gz file /home/user/helios-engvm/tmp/helios-qemu-ttya-full.raw.gz...
extracting /home/user/helios-engvm/tmp/helios-qemu-ttya-full.raw.gz
moving /home/user/helios-engvm/tmp/helios-qemu-ttya-full.raw.gz.extracted -> /home/user/helios-engvm/input/helios-qemu-ttya-full.raw
checking hash on existing file /home/user/helios-engvm/input/helios-qemu-ttya-full.raw...
seed image downloaded ok
```

If you already have an instance of Helios running, you can *alternatively*
choose to create this image [manually](image/README.md).

### VM Creation

#### Choose a VM configuration

The default virtual machine settings (e.g., CPU count, disk size, memory size)
are stored in `config/defaults.sh`:

```
host ~/helios-engvm $ cat config/defaults.sh
VM=helios
POOL=default
INPUT_IMAGE=helios-qemu-ttya-full.raw
SIZE=30G
VCPU=2
MEM=$(( 2 * 1024 * 1024 ))
```

You can override them by making a new file under `config`; e.g.,

```
host ~/helios-engvm $ echo 'VCPU=8' >config/big.sh
host ~/helios-engvm $ echo 'MEM=$(( 8 * 1024 * 1024 ))' >>config/big.sh
```

#### Ensure the libvrt `default` network is activated

You can check the state of existing networks as such:

```
$ sudo virsh net-list --all
```

The output should include the `default` network as "active":

```
 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   no          yes
```

If it is not active, activate it:

```
$ sudo virsh net-start default
```

#### Create the VM

You can now create a virtual machine. If you chose to use a non-default config,
provide its name as the argument, which will override the default. E.g., for a
config called `big.sh`:

```
host ~/helios-engvm $ ./create.sh big
```

If everything goes well, you will be attached to the serial console of the
virtual machine which will boot into the Helios development image.  An account
will be created with the same username and uid as your account on the host
system, and your `authorized_keys` file will be copied into the guest.
Once boot and setup are complete, you should see a prompt that tells you
the IP address the guest was given; e.g.,

```
You should be able to SSH to your VM:

    ssh user@192.168.122.235
```

If you need to get into the root account on the console to debug something, the
development image ships with an empty root password to make it easy to do so.

You can halt the VM and destroy the created resources (disks, etc) with the
matching `destroy.sh`:

```
host ~/helios-engvm $ ./destroy.sh big
```

If you need to get back on the console later, you can use the `console.sh`
script; e.g.,

```
host ~/helios-engvm $ ./console.sh big
```

## Building Helios and illumos software

Once you have a virtual machine running Helios and you are able to use SSH to
access it, you can build and test Helios and illumos software inside, like you
would with any other machine.  There are detailed instructions in the
[Helios](https://github.com/oxidecomputer/helios.git) repository that cover
building OS packages and updating the build machine (in this case, your virtual
machine!) to use those packages.

**NOTE**: As mentioned in the Helios documentation, when installing and
rebooting it is a good idea to be on the console of the virtual machine so you
can see any boot messages and interact with the boot loader.  If you are not
still attached from when you created the virtual machine, you can re-attach
with:

```
host$ virsh console --force helios
Connected to domain helios
Escape character is ^]

helios console login: root
Password:
Dec  4 22:58:11 helios login: ROOT LOGIN /dev/console
The illumos Project     master-0-g7b4214534c    December 2020
root@helios:~# reboot
Dec  4 22:58:49 helios reboot: initiated by root on /dev/console
updating /platform/i86pc/amd64/boot_archive (CPIO)
syncing file systems... done
rebooting...
```
## Installing on a physical machine using the ISO

If you want to install the OS on a physical machine, there is a crude
installation image available that can be booted as either an ISO or a USB disk.

First, grab the images from the download area at:
https://pkg.oxide.computer/install/latest/

This directory contains three ISO images, each of which is configured to use a
different device for the operating system console; `ttya` (aka COM1), `ttyb`
(aka COM2), or `vga` (the framebuffer and keyboard).  If you have a system with
an IPMI Serial-over-LAN (SOL) facility, you probably want `ttyb`.  If you have
a desktop with a keyboard and monitor, you probably want `vga`.  Prefer serial
if you can!

### Prepare installation media

If you have a physical USB mass storage device (e.g., a flash drive) you can
use `dd` to write the image to the disk.  It should replace the partition
table, so use the whole-disk device for your OS (e.g., something like
`/dev/sda` on Linux, or `/dev/dsk/c0t0d0p0` on illumos).

If you want to try booting the ISO via IPMI remote media redirection that may
also work.

### Initial install

Boot from your media.  The install media will log in automatically as **root**
and display an informational banner:

```
 -- Welcome to Oxide Helios! -------------------------------------------------

    This bootable ISO allows you to install Helios on a traditional
    install-to-disk system; e.g., a desktop PC or a BIOS/EFI-boot
    server.

    To install, use "diskinfo" to locate the disk you wish to install
    to, and then use "install-helios" to format it and install the
    operating system.

    More information is available in the "Installing on a physical
    machine using the ISO" section of the README at:

        https://github.com/oxidecomputer/helios-engvm

 -----------------------------------------------------------------------------
```

From this shell:

* Run `diskinfo` to find your disk; you may need to run it a few times if the
  disk devices have not yet finished attaching and you don't see the disks you
  expect.  For example:
  ```
  # diskinfo
  TYPE  DISK                    VID      PID              SIZE          RMV SSD
  NVME  c1t0025385C9150D623d0   Samsung  SSD 970 EVO 1TB   931.51 GiB   no  yes
  NVME  c2t0014EE83021EAE80d0   NVMe     WUS4BB019D4M9E4  1788.50 GiB   no  yes
  ```
* Choose a hostname.
* Run the installer, providing the hostname you've chosen and the disk onto
  which you wish to install; e.g.,
  ```
  # install-helios myhostname c1t0025385C9150D623d0
  ...
  ok to reboot now
  ```
* Once you get the **"ok to reboot now"** prompt, you should be able to remove
  the media and boot from your installed disk.
* After reboot, log in with `root` and no password.

### Configure networking

Find your NIC:

```
# dladm show-ether
LINK            PTYPE    STATE    AUTO  SPEED-DUPLEX                    PAUSE
bge0            current  up       yes   1G-f                            none
bge1            current  unknown  no    0G                              none

# dladm show-phys -m
LINK         SLOT     ADDRESS            INUSE CLIENT
bge0         primary  a0:42:3f:42:91:50  yes  bge0
bge1         primary  a0:42:3f:42:91:51  no   --
```

Let's say we pick `bge0`.  Set up IP:

```
# ipadm create-if bge0
# ipadm create-addr -T dhcp -h myhostname bge0/dhcp
# svcadm restart network/service
# ipadm show-addr
ADDROBJ           TYPE     STATE        ADDR
lo0/v4            static   ok           127.0.0.1/8
bge0/dhcp         dhcp     ok           172.20.3.63/24
lo0/v6            static   ok           ::1/128
```

### Create your user account

Clone `helios-engvm.git` on your workstation, and try generating a setup
script:

```
$ ./aws/gen_userdata.sh
#!/bin/bash
set -o errexit
set -o pipefail
set -o xtrace
echo 'Just a moment...' >/dev/msglog
/sbin/zfs create 'rpool/home/jclulow'
/usr/sbin/useradd -u '1000' -g staff -c 'Joshua M. Clulow' -d '/home/jclulow' \
    -P 'Primary Administrator' -s /bin/bash 'jclulow'
/bin/passwd -N 'jclulow'
/bin/mkdir '/home/jclulow/.ssh'
/bin/uudecode <<'EOSSH'
begin-base64 600 /home/jclulow/.ssh/authorized_keys
ZWNkc2Etc2hhMi1uaXN0cDM4NCBBQUFBRTJWalpITmhMWE5vWVRJdGJtbHpk
SEF6T0RRQUFBQUlibWx6ZEhBek9EUUFBQUJoQlBKNXU0d1pqdmUrUDFTQTEx
Q1U1WDVIcytGY29RQnFLZFpjMVA3MjhLS1dtbTBTK3YwVHMyR0Z1SldVcnV6
NnpDVm1JM3JWc2J4TGZ4cXFLbHZ6d0xrWXRhOU41aFZBakZhOTltQzRkYk1i
UlFWVFJrdW42ZXZPK3RvaTlCcXU2dz09IGpjbHVsb3ctc3lzbWdyLTAyCg==
====
EOSSH
/bin/chown -R 'jclulow:staff' '/home/jclulow'
/bin/chmod 0700 '/home/jclulow'
/bin/sed -i \
    -e '/^PATH=/s#$#:/opt/ooce/bin:/opt/ooce/sbin#' \
    /etc/default/login
/bin/ntpdig -S 0.pool.ntp.org || true
echo 'ok go' >/dev/msglog
```

If this works, you can go to the Helios machine and listen with netcat for a
script:

```
$ nc -l 1701 </dev/null | bash -x
```

Then, on your workstation:

```
$ ./aws/gen_userdata.sh | nc 172.20.3.63 1701
```

This should send the script to the Helios machine and create your account.
Assuming it completed successfully you should be able to SSH to the machine now
with your key:

```
$ ssh 172.20.3.63
The illumos Project     helios-1.0.20642        August 2021
jclulow@myhostname ~ $
```

### Configure multicast DNS

If you're using DHCP, your IP address may change from time to time.  On your
Helios machine you can enable Multicast DNS:

```
# svcadm enable network/dns/multicast
```

You should then be able to find the machine from your workstation as
`myhostname.local`, rather than needing to use the IP address.

### Configure swap

You should probably create a swap device if you don't already have one.
Determining the size is not an exact science, but somewhere between 1GB and
half the size of RAM is probably a good guess.

```
# zfs create -V 8G rpool/swap
# echo '/dev/zvol/dsk/rpool/swap - - swap - no -' >> /etc/vfstab
# /sbin/swapadd
```

### Configure a dump device

Also useful is to configure a dump device for capturing system crash dumps:

```
# zfs create -V 8G rpool/dump
# dumpadm -d /dev/zvol/dsk/rpool/dump
```

The dump device needs to be large enough to hold a compressed copy of all of
the allocated kernel memory in a system.  The most correct answer for sizing is
"the same size as physical RAM", but you can often get away with less.  You can
estimate how large a dump would be if the system panicked right now with
`dumpadm -e`, but note that this estimate does not reflect how large a dump
might be after you begin seriously using the system.

### Updating your system

Neither the ISO nor the virtual machine images always include the latest
packages.  You can update your system via:

```
# pkg update -v
```

Pay careful attention to the instructions printed at the end of the update.
You may be told that a _boot environment_ was created and that you need to
reboot to activate it.  You should do that with the `reboot` command before
moving on.

You can do this again whenever you need to update your system.

### Installing packages for building software

Unlike the `create.sh` script for producing a virtual machine, the ISO images
will install a minimal base system that does not include developer tools.  If
you are setting up a machine for developing (or just building) Helios and other
software, install at least these extra packages:

```
# pkg install -v \
    /developer/build-essential \
    /developer/illumos-tools
```

This will make available a variety of tools like Git, GNU Make, and GCC.

### Installing Rust and Cargo using Rustup

Official Rust and Cargo binaries are available from the Rust project via the
same [rustup](https://rustup.rs/) tool that works on other systems.  Use the
official instructions, but substitute `bash` anywhere you see `sh`; e.g., at
the time of writing, the (modified) official install instructions are:

```
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash
```

## Licence

Copyright 2024 Oxide Computer Company

Unless otherwise noted, all components are licenced under the [Mozilla Public
License Version 2.0](./LICENSE).
