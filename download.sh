#!/bin/bash

set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

namebase=helios-qemu-ttya-full
name=$namebase-20210309.raw
namegz=$name.gz
url="https://pkg.oxide.computer/seed/$namegz"
sha256="b285cc5f807c0872c9a53b2265f1343f4ead5d0bb63edcedebd145ca1bf9f36d"
sha256gz="24413cc62ba5552d3fe5608da0460dc711fda35defc51c393829ffa89e76c930"
sizegz=3051294786
oldsha="d67d86e2b0409eb0c21c32b5e3a63abf7963b91685c470c89c23ba09bd77ceb0"

function hash {
	shasum -a 256 "$1" | awk '{ print $1 }'
}

function filesize {
	if [[ $(uname) == Darwin ]]; then
		stat -f %z "$1"
	else
		stat -c %s "$1"
	fi
}

mkdir -p "$TOP/input"
mkdir -p "$TOP/tmp"

#
# Our original seed image did not have a date in the file name.  For now,
# remember the hash of the old image and move it aside to a name that does
# include the correct date.  These images are huge and it would be unfortunate
# to make people download them a second time.
#
o="$TOP/input/$namebase.raw"
if [[ ! -L "$o" && -f "$o" ]]; then
	echo "checking hash on existing file $o..."

	h=$(hash "$o")
	if [[ $h == $oldsha ]]; then
		echo "detected old seed image, moving aside"
		mv "$o" "$TOP/input/$namebase-20201204.raw"
	fi
fi

while :; do
	t="$TOP/input/$name"
	if [[ -f "$t" ]]; then
		echo "checking hash on existing file $t..."

		h=$(hash "$t")
		if [[ $h == $sha256 ]]; then
			echo "seed image downloaded ok"
			break
		fi

		echo "seed image hash does not match, removing"
		rm -f "$t"
	fi

	#
	# We try to continue downloading a partial file, as the image is quite
	# large.
	#
	g="$TOP/tmp/$namegz"
	if [[ "$(filesize "$g")" != $sizegz ]]; then
		echo "downloading gz file $url..."
		if ! curl -C - -f -o "$g" "$url"; then
			echo "download failure, retrying..."
			sleep 3
			continue
		fi
	else
		echo "gzip file $g is correct size, skipping download"
	fi

	echo "checking hash on existing gz file $g..."
	h=$(hash "$g")
	if [[ $h != $sha256gz ]]; then
		echo "seed image gz not ok, removing"
		rm -f "$g"
		continue
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

#
# Create a symbolic link that points the base name (without a timestamp) to the
# image we just downloaded.
#
rm -f "$TOP/input/$namebase.raw"
ln -s "$name" "$TOP/input/$namebase.raw"
