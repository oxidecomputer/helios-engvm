#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

MACHINE=${MACHINE:-generic}
CONSOLE=${CONSOLE:-ttya}
VARIANT=${VARIANT:-ufs}
GROUP=${GROUP:-helios}
EXTRA=
TARNAME='helios-dev'

ARGS=()

while getopts 'o:NOS' c; do
	case "$c" in
	N)
		printf 'ERROR: -N is no longer supported; use -o\n' >&2
		exit 1
		;;
	o)
		OPTE_VER="$OPTARG"
		EXTRA="-opte-$OPTE_VER"
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'opte' )
		;;
	O)
		EXTRA='-onu'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		;;
	S)
		EXTRA='-serdev'
		TARNAME="helios$EXTRA"
		ARGS+=( '-N' "$MACHINE$EXTRA-$CONSOLE-$VARIANT" )
		ARGS+=( '-F' 'serdev' )
		;;
	\?)
		printf 'usage: %s [-CO] [-o OPTE_VER]\n' "$0" >&2
		exit 2
		;;
	esac
done
shift $((OPTIND - 1))

cd "$TOP"

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d "$DATASET" \
    -g "$GROUP" \
    -n "$MACHINE-$CONSOLE-$VARIANT" \
    -T "$TOP/templates" \
    -F "name=$TARNAME" \
    "${ARGS[@]}"

ls -lh "$MOUNTPOINT/output/$GROUP-$MACHINE$EXTRA-$CONSOLE-$VARIANT.ufs"
