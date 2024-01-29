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

set -o errexit
set -o pipefail
set -o xtrace

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
VARIANT=ramdisk ./strap.sh -f -S
MACHINE=builder ./ufs.sh

#
# Record some information about the packages that went into the image:
#
mkdir -p /out/meta
pkg -R /rpool/images/work/helios/ramdisk/.zfs/snapshot/image \
    contents -m | gzip > /out/meta/pkg_contents.txt.gz
pkg -R /rpool/images/work/helios/ramdisk/.zfs/snapshot/image \
    list -v > /out/meta/pkg_list.txt

MOUNTPOINT=/rpool/images

#
# Produce an archive that contains the kernel and ramdisk image in the correct
# layout for iPXE boot on the buildomat lab factory:
#
mkdir -p "/proto/platform/i86pc/amd64"
mkdir -p "/proto/platform/i86pc/kernel/amd64"

cd /proto &&
    tar xvf \
    "$MOUNTPOINT/output/helios-dev-ramdisk-boot.tar" \
    'platform/i86pc/kernel/amd64/unix'

cp "$MOUNTPOINT/output/helios-builder-ttya-ufs.ufs" \
    '/proto/platform/i86pc/amd64/boot_archive'

digest -a sha1 \
    '/proto/platform/i86pc/amd64/boot_archive' \
    > '/proto/platform/i86pc/amd64/boot_archive.hash'

find '/proto' -type f -ls

cd /proto &&
    tar cvfz /out/ramdisk-builder.tar.gz *

find '/out' -type f -ls
