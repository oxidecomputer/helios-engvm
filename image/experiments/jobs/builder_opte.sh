#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

#
# This job script is run inside a buildomat ephemeral VM.
#
if [[ -z $BUILDOMAT_JOB_ID ]]; then
	printf 'ERROR: this is supposed to be run under buildomat.\n' >&2
	exit 1
fi

if [[ -z $OPTE_VER ]]; then
	printf 'ERROR: specify OPTE_VER in job environment.\n' >&2
	exit 1
fi

set -o errexit
set -o pipefail
set -o xtrace

#
# Try to update pkg(1), in case there are new features that we will need to
# build an image with current OS bits:
#
if ! pkg update -v pkg; then
	rc=$?
	if (( $rc != 4 )); then
		printf 'ERROR: pkg update failed with status %d\n' "$rc" >&2
		exit 1
	fi
fi

#
# Install the omicron1 zone brand tools:
#
if ! pkg install -v /system/zones/brand/omicron1/tools; then
	rc=$?
	if (( $rc != 4 )); then
		printf 'ERROR: pkg install failed with status %d\n' "$rc" >&2
		exit 1
	fi
fi

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
echo 'DATASET=rpool/images' >> /work/image/etc/config.sh

#
# Check out and build the tools we need:
#
BUILD_AWS_WIRE_LENGTHS=no \
    BUILD_METADATA_AGENT=no \
    ./setup.sh

#
# Build the image:
#
VARIANT=ramdisk ./strap.sh -f -o "$OPTE_VER" -B
MACHINE=builder ./ufs.sh -o "$OPTE_VER"

#
# Record some information about the packages that went into the image:
#
mountpoint=/rpool/images
workroot="$mountpoint/work/helios/ramdisk-opte"
mkdir -p /out/meta
pkg -R "$workroot/.zfs/snapshot/image" contents -m | gzip \
    > /out/meta/pkg_contents.txt.gz
pkg -R "$workroot/.zfs/snapshot/image" list -Hv | sort \
    > /out/meta/pkg_list.txt

#
# Produce an archive that contains the kernel and ramdisk image in the correct
# layout for iPXE boot on the buildomat lab factory:
#
mkdir -p "/proto/platform/i86pc/amd64"
mkdir -p "/proto/platform/i86pc/kernel/amd64"

cd /proto &&
    tar xvf \
    "$mountpoint/output/helios-opte-$OPTE_VER-ramdisk-boot.tar" \
    'platform/i86pc/kernel/amd64/unix'

cp "$mountpoint/output/helios-builder-opte-$OPTE_VER-ttya-ufs.ufs" \
    '/proto/platform/i86pc/amd64/boot_archive'

digest -a sha1 \
    '/proto/platform/i86pc/amd64/boot_archive' \
    > '/proto/platform/i86pc/amd64/boot_archive.hash'

find '/proto' -type f -ls

cd /proto &&
    tar cvfz "/out/ramdisk-builder-opte-$OPTE_VER.tar.gz" *

find '/out' -type f -ls
