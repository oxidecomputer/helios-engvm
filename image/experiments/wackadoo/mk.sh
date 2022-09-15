#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

WACKADOO=$(cd "$(dirname "$0")" && pwd)
TOP=$(cd "$(dirname "$0")/../.." && pwd)
. "$TOP/lib/common.sh"
cd "$TOP"

GATE=${GATE:-/ws/stlouis}
HELIOS=${HELIOS:-/ws/helios}
PHBL=${PHBL:-/ws/phbl}
AMD_HOST_IMAGE_BUILDER=${AMD_HOST_IMAGE_BUILDER:-/ws/amd-host-image-builder}
PINPRICK=${PINPRICK:-/ws/pinprick/target/release/pinprick}
BANNER=${BANNER:-/ws/prombanner/target/release/prombanner}
MKIMAGE=${MKIMAGE:-/ws/bootserver/target/release/mkimage}

OUTDIR=/tmp/wackadoo.$LOGNAME

case "$1" in
full)
	"$BANNER" pkgs
	"$HELIOS"/helios-build onu -P -g "$GATE" -s wackadoo

	"$BANNER" strap
	VARIANT=ramdisk ./strap.sh -S -E \
	    -O "$HELIOS/tmp/onu.wackadoo/repo.redist"
	;;
quick)
	"$BANNER" quick
	VARIANT=ramdisk ./strap.sh -S -E -A \
	    -O "$HELIOS/tmp/onu.wackadoo/repo.redist"
	;;
none)
	;;
*)
	printf 'ERROR: type should be full|quick|none\n' >&2
	exit 1
esac

case "$1" in
full|quick)
	"$BANNER" zfs
	./zfs.sh -O -E
	;;
esac

rm -rf "$OUTDIR"
mkdir -m 0700 -p "$OUTDIR"

ROOT="$MOUNTPOINT/work/helios/ramdisk-onu"

"$BANNER" image
"$MKIMAGE" \
    -i "$MOUNTPOINT/output/helios-generic-onu-ttya-zfs.raw" \
    -o "$OUTDIR/zfs.img"

#
# The image contains a SHA-256 hash that we need to extract and include in the
# CPIO archive.
#
dd if="$OUTDIR/zfs.img" bs=1 count=32 iseek=24 > "$OUTDIR/boot_image_csum"

"$BANNER" cpio
(cd "$ROOT" && cpio -qo -H odc -O "$OUTDIR/cpio") <"$WACKADOO/cpiofiles.txt"
(cd "$OUTDIR" && cpio -qo -H odc -AO "$OUTDIR/cpio") <<<boot_image_csum

#
# Create compressed versions of unix and the cpio for nanobl-rs:
#
"$BANNER" cpio.z
"$PINPRICK" "$OUTDIR/cpio" >"$OUTDIR/cpio.z"
"$BANNER" unix.z
"$PINPRICK" "$ROOT/platform/oxide/kernel/amd64/unix" >"$OUTDIR/unix.z"

#
# Create the reset image for the Gimlet SPI ROM:
#
"$BANNER" phbl
(cd "$PHBL" && cargo xtask build --release --cpioz "$OUTDIR/cpio.z")
"$BANNER" rom
(cd "$AMD_HOST_IMAGE_BUILDER" &&
    target/debug/amd-host-image-builder \
    -B amd-firmware/GN/1.0.0.1 \
    -B amd-firmware/GN/1.0.0.6 \
    --config etc/milan-gimlet-b.efs.json5 \
    --output-file "$OUTDIR/rom" \
    --reset-image "$PHBL/target/x86_64-oxide-none-elf/release/phbl")

ls -lh "$OUTDIR"
