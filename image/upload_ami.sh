#!/bin/bash
#
# Upload a raw disk image into AWS and register it as an AMI.  The image must
# have been built first, and at a location of the form:
#
#     /rpool/images/output/helios-aws-vga-base.raw
#
# This tool requires "setup.sh" and "aws.sh" to have been run first to create
# the image.
#

#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

AMI_NAME=$1
if [[ -z "$AMI_NAME" ]]; then
	printf 'ERROR: usage: %s <ami_name>\n' "$0" >&2
	exit 1
fi

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

VARIANT=${VARIANT:-base}
FILE="$MOUNTPOINT/output/helios-aws-vga-$VARIANT.raw"

if [[ ! -f "$FILE" ]]; then
	printf 'image file %s does not exist yet?\n' "$FILE" >&2
	exit 1
fi

cd "$TOP"

AWL="$TOP/aws-wire-lengths/target/release/aws-wire-lengths"

time "$AWL" image publish \
    -E \
    -f "$FILE" \
    -n "$AMI_NAME"

#
# Grant access to some of our other AWS accounts:
#
accts=(
	'620872736810'		# buildomat
)
for a in "${accts[@]}"; do
	"$AWL" image grant "$AMI_NAME" "$a"
done
