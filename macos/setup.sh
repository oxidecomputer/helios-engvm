#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

cd "$TOP"
if [[ ! -d vmware-sercons ]]; then
	git clone git@github.com:jclulow/vmware-sercons.git \
	    vmware-sercons
fi

(cd vmware-sercons && make)
