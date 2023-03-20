#!/bin/bash

set -o errexit
set -o pipefail

printf 'WARNING: this script is being replaced with "gmake setup"\n' >&2

set -o xtrace

cd "$(dirname "$0")"
gmake setup
