#!/bin/bash
#
# Copy ramdisk artefacts for the coffee lab machines into the web root for iPXE
# boot.
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

HTDOCS=/data/www/htdocs/coffee

mkdir -p "$HTDOCS/ramdisk"

cd "$HTDOCS/ramdisk" &&
    tar xvfz \
    "$MOUNTPOINT/output/helios-coffee-ramdisk-boot.tar.gz" \
    platform/i86pc/kernel/amd64/unix

mkdir -p "$HTDOCS/ramdisk/platform/i86pc/amd64"
cp "$MOUNTPOINT/output/helios-builder-coffee-ttya-ufs.ufs" \
    "$HTDOCS/ramdisk/platform/i86pc/amd64/boot_archive"

digest -a sha1 \
    "$HTDOCS/ramdisk/platform/i86pc/amd64/boot_archive" \
    > "$HTDOCS/ramdisk/platform/i86pc/amd64/boot_archive.hash"

find "$HTDOCS/ramdisk/" -type f -ls
