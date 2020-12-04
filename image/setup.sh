#!/bin/bash

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

cd "$TOP"
if [[ ! -d image-builder ]]; then
	git clone git@github.com:jclulow/illumos-image-builder.git \
	    image-builder
fi

if [[ ! -d metadata-agent ]]; then
	git clone git@github.com:illumos/metadata-agent.git \
	    metadata-agent
fi

(cd image-builder && cargo build --release)
(cd metadata-agent && cargo build --release)

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

pfexec "$TOP/image-builder/target/release/image-builder" \
    build \
    -d rpool/images \
    -g helios \
    -n qemu-ttya-full \
    -T "$TOP/templates"

