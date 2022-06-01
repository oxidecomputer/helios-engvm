#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

DATASET=rpool/images
MOUNTPOINT="$(zfs get -Ho value mountpoint "$DATASET")"
MACHINE=${MACHINE:-generic}
CONSOLE=${CONSOLE:-ttya}
VARIANT=${VARIANT:-ufs}
EXTRA=
TARNAME='helios-dev'

TOP=$(cd "$(dirname "$0")" && pwd)

ARGS=()

while getopts 'CN' c; do
	case "$c" in
	N)
		EXTRA='-netdev'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'netdev' )
		;;
	C)
		EXTRA='-coffee'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'coffee' '-F' 'ssh' )
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
    "${ARGS[@]}"

ls -lh "$MOUNTPOINT/output/helios-$MACHINE$EXTRA-$CONSOLE-$VARIANT.ufs"
