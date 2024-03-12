#!/bin/bash
#
# Produce a raw disk image suitable for use with AWS, based on a seed tar file
# and some set of additional customisations (e.g., adding a metadata agent or
# additional OS packages).  Will output an uncompressed raw disk image at,
# e.g.,
#
#	/rpool/images/output/helios-aws-ttya-base.raw
#
# This tool requires "setup.sh" and "strap.sh" to have been run first.
#

#
# Copyright 2024 Oxide Computer Company
#

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

export MACHINE=${MACHINE:-aws}
export CONSOLE=${CONSOLE:-ttya}
export VARIANT=${VARIANT:-base}

#
# The AWS image build is now sufficiently similar to all the others that we can
# just delegate here:
#
exec "$TOP/image.sh" "$@"
