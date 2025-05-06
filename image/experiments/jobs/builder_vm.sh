#!/bin/bash
#
# Copyright 2025 Oxide Computer Company
#


#
# This job script is run inside a buildomat ephemeral VM.
#
if [[ -z $BUILDOMAT_JOB_ID ]]; then
	printf 'ERROR: this is supposed to be run under buildomat.\n' >&2
	exit 1
fi

set -o errexit
set -o pipefail
set -o xtrace

#
# We need to work around the confluence of several unfortunate issues.  Our use
# of the ZFS "autoexpand" property means that the system currently spuriously
# relabels the lofi-backed pool, even though it has not changed sized since it
# was created moments before.  This triggers a ZFS-level reopen of the device
# (which, for disk-based vdevs, does not _actually_ close and reopen the LDI
# handle), which currently fails because the label was just invalidated.
#
# The DTrace program here will pause the execution of syseventd (where the ZFS
# sysevent module is resident) after it has relabelled the device, but before
# it has asked ZFS to reopen the pool.  At that point, we perform our own open
# and close of the device using dd(8), which is enough to get lofi and cmlb to
# reload the label.  This allows the subsequent reopen to succeed.
#
bmat process start workaround pfexec dtrace -qw -p $(pgrep -x syseventd) -n '
pid$target::zpool_relabel_disk:entry
{
        self->hdl = args[0];
        this->name = copyinstr(arg1);
        this->msg = copyinstr(arg2);

        printf("%s(%p, %s, %s)\n", probefunc, self->hdl, this->name, this->msg);
}

syscall::open:entry
/self->hdl != 0 && self->path == 0/
{
        self->path = copyinstr(arg0);
        printf("  ^ device name: %s\n", self->path);
}

pid$target::zpool_relabel_disk:return
/self->hdl != 0 && (this->r = (int)arg1) != 0/
{
        printf("%s(%p) failed with %d\n", probefunc, self->hdl, this->r);

        self->hdl = 0;
        self->path = 0;
}

pid$target::zpool_relabel_disk:return
/self->hdl != 0 && ((int)arg1) == 0/
{
        printf("%s(%p) succeeded!\n", probefunc, self->hdl);

        stop();
        system("dd if=%s of=/dev/null bs=512 count=1; prun %d", self->path,
            pid);

        self->hdl = 0;
        self->path = 0;
}
'

function pkg_maybe {
	if pkg "$@"; then
		echo "pkg $1 ok"
	else
		rc=$?
		if (( $rc != 4 )); then
			printf 'ERROR: pkg %s failed with status %d\n' "$1" \
			    "$rc" >&2
			exit 1
		fi
		echo "pkg $1 ok (no action needed)"
	fi
}

#
# Try to update pkg(1), in case there are new features that we will need to
# build an image with current OS bits:
#
pkg_maybe update -v pkg
pkg_maybe install -v /compress/zstd

#
# Install a stable Rust toolchain so that we can build the image builder:
#
RUSTUP_INIT_SKIP_PATH_CHECK=yes \
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s - \
    --default-toolchain stable \
    --profile minimal \
    --no-modify-path \
    -y -q

. "$HOME/.cargo/env"

#
# Create datasets to work in:
#
zfs create rpool/images
zfs create -o mountpoint=/work rpool/work
zfs create -o mountpoint=/proto rpool/proto
zfs create -o mountpoint=/out rpool/out

cd /work

#
# Unpack the templates and scripts we included when kicking off the job:
#
gunzip < '/input/image.cpio.gz' | cpio -idv

cd /work/image

#
# Override whatever dataset is nominated locally as it will not make sense in
# the CI environment.
#
dataset='rpool/images'
mountpoint="/$dataset"
echo "DATASET=$dataset" >> /work/image/etc/config.sh

#
# Unpack the input image from the previous job stage.
#
zfs create -p "$dataset/output"
time zstd -o "$mountpoint/output/helios-dev-full.tar" -k -d \
    "/input/full-tar/out/helios-dev-full.tar.zst"

#
# Check out and build the tools we need:
#
BUILD_AWS_WIRE_LENGTHS=no \
    gmake setup

#
# Build the images:
#
for m in aws builder; do
	VARIANT=full CONSOLE=ttya MACHINE="$m" time ./image.sh
done

#
# Compress them:
#
for m in aws builder; do
	time zstd -o "/out/helios-$m-ttya-full.raw.zst" -k -7 \
	    "$mountpoint/output/helios-$m-ttya-full.raw"
done

find '/out' -type f -ls
