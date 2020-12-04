# Helios Engineering VM Tools

This repository contains tools for setting up a Helios VM on a Linux
workstation for development purposes.

## Creating your Helios virtual machine

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

To create the virtual machine, you must first obtain the seed image:

```
host ~/helios-engvm $ ./download.sh
checking hash on existing gz file /home/user/helios-engvm/tmp/helios-qemu-ttya-full.raw.gz...
extracting /home/user/helios-engvm/tmp/helios-qemu-ttya-full.raw.gz
moving /home/user/helios-engvm/tmp/helios-qemu-ttya-full.raw.gz.extracted -> /home/user/helios-engvm/input/helios-qemu-ttya-full.raw
checking hash on existing file /home/user/helios-engvm/input/helios-qemu-ttya-full.raw...
seed image downloaded ok
```

The default virtual machine settings (e.g., CPU count, disk size, memory size)
are stored in `config/defaults.sh`:

```
host ~/helios-engvm $ cat config/defaults.sh
VM=helios
POOL=default
SIZE=30G
VCPU=2
MEM=$(( 2 * 1024 * 1024 ))
```

You can override them by making a new file under `config`; e.g.,

```
host ~/helios-engvm $ echo 'VCPU=8' >config/big.sh
host ~/helios-engvm $ echo 'MEM=$(( 8 * 1024 * 1024 ))' >>config/big.sh
```

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
