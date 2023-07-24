#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

MACHINE=${MACHINE:-generic}
CONSOLE=${CONSOLE:-ttya}
VARIANT=${VARIANT:-zfs}
EXTRA=
TARNAME='helios-dev'
BAUD=115200

ARGS=()

while getopts '3CNO' c; do
	case "$c" in
	3)
		BAUD=3000000
		;;
	N)
		printf 'ERROR: -N is no longer supported; use -o\n' >&2
		exit 1
		;;
	C)
		EXTRA='-coffee'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'coffee' '-F' 'ssh' )
		;;
	O)
		EXTRA='-onu'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		;;
	esac
done
shift $((OPTIND - 1))

cd "$TOP"

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g helios \
    -n "$MACHINE-$CONSOLE-$VARIANT" \
    -T "$TOP/templates" \
    -F "name=$TARNAME" \
    -F "baud=$BAUD" \
    "${ARGS[@]}"

ls -lh "$MOUNTPOINT/output/helios-$MACHINE$EXTRA-$CONSOLE-$VARIANT.raw"
