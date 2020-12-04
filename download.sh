#!/bin/bash

set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

name=helios-qemu-ttya-full.raw
namegz=$name.gz
url="https://pkg.oxide.computer/seed/$namegz"
sha256="d67d86e2b0409eb0c21c32b5e3a63abf7963b91685c470c89c23ba09bd77ceb0"
sha256gz="0cc976ab6cd34e6eef406ea8667ee2544ff8fbd63eddcdb3c59359d3aa7eadf1"

function hash {
	sha256sum "$1" | awk '{ print $1 }'
}

mkdir -p "$TOP/input"
mkdir -p "$TOP/tmp"

while :; do
	t="$TOP/input/$name"
	if [[ -f "$t" ]]; then
		echo "checking hash on existing file $t..."

		h=$(hash "$t")
		if [[ $h == $sha256 ]]; then
			echo "seed image downloaded ok"
			exit 0
		fi

		echo "seed image hash does not match, removing"
		rm -f "$t"
	fi

	g="$TOP/tmp/$namegz"
	if [[ -f "$g" ]]; then
		echo "checking hash on existing gz file $g..."

		h=$(hash "$g")
		if [[ $h != $sha256gz ]]; then
			echo "seed image gz not ok, removing"
			rm -f "$g"
			continue
		fi
	else
		echo "downloading gz file $url..."
		if ! curl -f -o "$g" "$url"; then
			echo "download failure, retrying..."
			rm -f "$g"
			sleep 3
			continue
		fi
	fi

	echo "extracting $g"
	rm -f "$g.extracted"
	if ! gunzip < "$g" > "$g.extracted"; then
		echo "could not extract"
		exit 1
	fi

	echo "moving $g.extracted -> $t"
	if ! mv "$g.extracted" "$t"; then
		echo "could not move file into place"
		exit 1
	fi
done
