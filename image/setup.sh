#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)
. "$TOP/lib/common.sh"

#
# Check if the dataset we're going to use for temporary files and build output
# exists already:
#
if [[ "$(zfs list -Ho name "$DATASET" 2>/dev/null)" != "$DATASET" ]]; then
	pfexec zfs create -o compress=on "$DATASET"
fi

cd "$TOP"
if [[ ! -d image-builder ]]; then
	git clone git@github.com:illumos/image-builder.git \
	    image-builder
else
	(cd image-builder && git pull --rebase)
fi

if [[ ! -d metadata-agent ]]; then
	git clone git@github.com:illumos/metadata-agent.git \
	    metadata-agent
else
	(cd metadata-agent && git pull --rebase)
fi

if [[ ! -d aws-wire-lengths ]]; then
	git clone git@github.com:oxidecomputer/aws-wire-lengths.git \
	    aws-wire-lengths
else
	(cd aws-wire-lengths && git pull --rebase)
fi

(cd image-builder && cargo build --release)
(cd metadata-agent && cargo build --release)
(cd aws-wire-lengths && cargo build --release)

for f in \
    metadata \
    metadata.xml \
    userscript.sh \
    userscript.xml; do
	ff="$TOP/templates/files/$f"
	rm -f "$ff"
	if [[ $f == metadata ]]; then
		cp "$TOP/metadata-agent/target/release/$f" "$ff"
	else
		cp "$TOP/metadata-agent/$f" "$ff"
	fi
done
