# Helios Engineering System Tools

This repository contains tools for setting up a Helios virtual or physical host
for development purposes.  It provides support for at least the following
environments:

* Linux workstation, Ubuntu 20.04.01 LTS, KVM/QEMU as managed by libvirt
* Macintosh workstation, VMware Fusion 12

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

##### Bridged Network on Ubuntu 22.04

NOTE: This only works for wired interfaces.

In some cases, it's useful to bridge a VM to your local network. This allows accessing the VM
on your the same LAN as your Linux host. The following script adds a bridge, `virbr1`, to your host
ethernet interface. It sets it up for DHCP v4, which allows the VM to receive an IP address from
your local router. The script then creates a bridged network named `host-bridge` for use by libvirt.

First, find the name of your ethernet interface with `ip a` or `ifconfig`.

Then run the script. In this example, the ethernet interface is named `enp4s0`.

```
 sudo ./create-host-bridge.sh enp4s0
```

Lastly, apply the network interface changes to the host. 

**IMPORTANT**: This will cause you to lose your connection temporarily if you are SSH'd into the box.

```
sudo netplan apply
```


This bridge can be used by VMs by changing their configuration to use `NETWORK=host-bridge`.

#### Macintosh

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

The default virtual machine settings (e.g., CPU count, disk size, memory size)
are stored in `config/defaults.sh`:

```
host ~/helios-engvm $ cat config/defaults.sh
VM=helios
POOL=default
NETWORK=default
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

Note: If you created a host bridge for an ubuntu system, you can use that bridge by setting
`NETWORK=host-bridge` in the configuration similar to the examples above.

You can now create a virtual machine.  If you provide an argument, it is
the name of one of the override configuration files you have created within
the `config` directory, e.g.,

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

## Building illumos

This part of the process is a little rough, but here is the recommended path to
building and installing your own illumos packages within the VM:

First, SSH to the guest with your SSH agent forwarded (`-A`) so that you can
get to GitHub, and then clone the base helios repository:

```
$ ssh -A <YOUR_GUEST_IP>
user@helios:~$ cat /etc/release
  Oxide Helios 1
user@helios:~$
```

Now, clone the base Helios repository and run the setup process:

```
user@helios:~$ git clone git@github.com:oxidecomputer/helios.git
Cloning into 'helios'...
The authenticity of host 'github.com (192.30.255.113)' can't be established.
RSA key fingerprint is SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'github.com,192.30.255.113' (RSA) to the list of known hosts.
remote: Enumerating objects: 169, done.
remote: Counting objects: 100% (169/169), done.
remote: Compressing objects: 100% (60/60), done.
remote: Total 169 (delta 94), reused 160 (delta 85), pack-reused 0
Receiving objects: 100% (169/169), 57.67 KiB | 608.00 KiB/s, done.
Resolving deltas: 100% (94/94), done.

user@helios:~$ cd helios
user@helios:~/helios$ gmake setup
cd tools/helios-build && cargo build --quiet
...
Cloning into '/home/user/helios/projects/illumos'...
...

Setup complete!  ./helios-build is now available.

```

The Rust-based `helios-build` tool will be built and several repositories will
then be cloned under `projects/`.  Note that, at least for now, the tool takes
a little while to build the first time.

To make it easier to build illumos, `helios-build` provides several wrappers
that manage build configuration and invoke the illumos build tools.  The
upstream illumos documentation has a guide, [Building
illumos](https://illumos.org/docs/developers/build/), which covers most of what
the Helios tools are doing on your behalf if you are curious.

### Building and installing into the local virtual machine

You can perform a "quick" build, without most of the additional compilers or
static analysis that we require for final integration of changes, thus:

```
user@helios:~/helios$ ./helios-build build-illumos -q
Dec 04 22:04:49.214 INFO file /home/user/helios/projects/illumos/illumos-quick.sh does not exist
Dec 04 22:04:49.215 INFO writing /home/user/helios/projects/illumos/illumos-quick.sh ...
Dec 04 22:04:49.215 INFO ok!
Dec 04 22:04:49.216 INFO exec: ["/sbin/sh", "-c", "cd /home/user/helios/projects/illumos && ./usr/src/tools/scripts/nightly /home/user/helios/projects/illumos/illumos-quick.sh"]
...
```

Depending on how many CPUs you have given the guest, and the performance of
your local storage, this can take some time.  The full build log is quite
large, and can be seen via, e.g.,

```
user@helios:~/helios$ tail -F projects/illumos/log/nightly.log
```

Once your build has completed successfully, you can install it on the local
system and reboot into it with the `onu` wrapper:

```
user@helios:~/helios$ ./helios-build onu -t my-be-name
Dec 04 22:55:49.470 INFO creating temporary repository...
...
Dec 04 22:58:11.798 INFO O| beadm activate my-be-name
Dec 04 22:58:11.945 INFO O| Activated successfully
Dec 04 22:58:11.994 INFO onu complete!  you must now reboot
user@helios:~/helios$
```

This will install the illumos packages you just built and create a new _Boot
Environment_ with the name you pass with `-t` (e.g., `my-be-name` above).
The new boot environment can be seen with `beadm list`, and has been
activated by `onu` so that you can reboot into it.

It is a good idea to be on the console so you can see any boot messages
and interact with the boot loader.  If you are not still attached from
when you created the virtual machine, you can re-attach with:

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

You can see that your updated packages are now running:

```
user@helios:~$ pkg list -Hv SUNWcs
pkg://on-nightly/SUNWcs@0.5.11-1.0.999999:20201204T223805Z                   i--
```

### Making changes

When making changes to the system I would generally recommend starting with a
pristine built workspace, as you would have in the previous section.

Once your build has completed, you may wish to make a change to a particular
source file and rebuild a component.  There are many components in the illumos
repository, but we can choose a simple one as an example here.  To build a
particular component, we must first use `bldenv` to enter the build
environment:

```
user@helios:~/helios$ ./helios-build bldenv
Dec 04 22:09:06.845 INFO file /home/user/helios/projects/illumos/illumos.sh does not exist
Dec 04 22:09:06.846 INFO writing /home/user/helios/projects/illumos/illumos.sh ...
Dec 04 22:09:06.846 INFO ok!
Build type   is  non-DEBUG
RELEASE      is
VERSION      is master-0-g4004e4c5da
RELEASE_DATE is December 2020

The top-level 'setup' target is available to build headers and tools.

Using /bin/bash as shell.
user@helios:~/helios/projects/illumos/usr/src$
```

A new interactive shell has been started, with `PATH` and other variables set
correctly, and you can now change to a component directory and build it:

```
user@helios:~/helios/projects/illumos/usr/src$ cd cmd/id
user@helios:~/helios/projects/illumos/usr/src/cmd/id$ dmake -m serial install
...
```

If you're changing something in the kernel and you want to reboot your guest
into a copy of illumos with your changes, run a new build and use `onu`
to install it as in the previous section.

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

Boot from your media.

* Log in as `root` with no password.
* Run `diskinfo` to find your disk; you may need to run it a few times if the
  disk devices have not yet finished attaching and you don't see the disks you
  expect.
* Choose a hostname.
* Run the installer.

```
# diskinfo
TYPE    DISK                    VID      PID              SIZE          RMV SSD
NVME    c1t0025385C9150D623d0   Samsung  SSD 970 EVO 1TB   931.51 GiB   no  yes
NVME    c2t0014EE83021EAE80d0   NVMe     WUS4BB019D4M9E4  1788.50 GiB   no  yes

# install-helios myhostname c1t0025385C9150D623d0
....
ok to reboot now
```

* Once you get the OK to reboot prompt, you should be able to remove the media
  and boot from your installed disk.
* After reboot, log in with `root` and no password again.

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
# ipadm create-addr -T dhcp bge0/dhcp
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
