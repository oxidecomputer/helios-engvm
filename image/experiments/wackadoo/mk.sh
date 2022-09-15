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

OUTDIR=/tmp/wackadoo.$LOGNAME

case "$1" in
full)
	banner pkgs
	"$HELIOS"/helios-build onu -P -g "$GATE" -s wackadoo

	banner strap
	VARIANT=ramdisk ./strap.sh -S -E \
	    -O "$HELIOS/tmp/onu.wackadoo/repo.redist"
	;;
quick)
	banner quick
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
	banner zfs
	./zfs.sh -O -E
	;;
esac

rm -rf "$OUTDIR"
mkdir -m 0700 -p "$OUTDIR"

ROOT="$MOUNTPOINT/work/helios/ramdisk-onu"

banner cpio
(cd "$ROOT" && cpio -qo -H odc) <"$WACKADOO/cpiofiles.txt" >"$OUTDIR/cpio"

#
# Create compressed versions of unix and the cpio for nanobl-rs:
#
banner cpio.z
"$PINPRICK" "$OUTDIR/cpio" >"$OUTDIR/cpio.z"
banner unix.z
"$PINPRICK" "$ROOT/platform/oxide/kernel/amd64/unix" >"$OUTDIR/unix.z"

#
# Create the reset image for the Gimlet SPI ROM:
#
banner phbl
(cd "$PHBL" && cargo xtask build --release --cpioz "$OUTDIR/cpio.z")
banner rom
(cd "$AMD_HOST_IMAGE_BUILDER" &&
    target/debug/amd-host-image-builder \
    -B amd-firmware/GN/1.0.0.1 \
    -B amd-firmware/GN/1.0.0.6 \
    --config etc/milan-gimlet-b.efs.json5 \
    --output-file "$OUTDIR/rom" \
    --reset-image "$PHBL/target/x86_64-oxide-none-elf/release/phbl")

banner zfs
cp "$MOUNTPOINT/output/helios-generic-onu-ttya-zfs.raw" "$OUTDIR/zfs"

ls -lh "$OUTDIR"
