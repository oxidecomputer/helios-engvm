#!/bin/bash
#
# Copy ramdisk artefacts for the coffee lab machines into the web root for iPXE
# boot.
#

HTDOCS=/data/www/htdocs/coffee

mkdir -p "$HTDOCS/ramdisk"

cd "$HTDOCS/ramdisk" &&
    tar xvfz \
    /rpool/images/output/helios-coffee-ramdisk-boot.tar.gz \
    platform/i86pc/kernel/amd64/unix

mkdir -p "$HTDOCS/ramdisk/platform/i86pc/amd64"
cp /rpool/images/output/helios-builder-coffee-ttya-ufs.ufs \
    "$HTDOCS/ramdisk/platform/i86pc/amd64/boot_archive"

digest -a sha1 \
    "$HTDOCS/ramdisk/platform/i86pc/amd64/boot_archive" \
    > "$HTDOCS/ramdisk/platform/i86pc/amd64/boot_archive.hash"

find "$HTDOCS/ramdisk/" -type f -ls
