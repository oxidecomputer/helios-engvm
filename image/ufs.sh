#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

MACHINE=${MACHINE:-generic}
CONSOLE=${CONSOLE:-ttya}
VARIANT=${VARIANT:-ufs}
EXTRA=
TARNAME='helios-dev'

ARGS=()

while getopts 'o:CNO' c; do
	case "$c" in
	N)
		EXTRA='-netdev'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'netdev' )
		;;
	o)
		OPTE_VER="$OPTARG"
		EXTRA="-opte-$OPTE_VER"
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'opte' )
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
	\?)
		printf 'usage: %s [-NCO] [-o OPTE_VER]\n' "$0" >&2
		exit 2
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
