#!/bin/bash
#
# This script can be ran locally or in CI for collecting the artifacts needed
# to build a netstack image

if [[ ! -f ~/.netrc ]]; then
    echo "You must setup a .netrc file with an api.github.com machine entry"
    echo "with a GitHub access token in order to access all needed artifacts"
    exit 1
fi

function get_current_branch {
    BRANCH=$(curl -n -sSf "https://api.github.com/repos/$REPO" |
        jq -r .default_branch)
    SHA=$(curl -n -sSf "https://api.github.com/repos/$REPO/branches/$BRANCH" |
        jq -r .commit.sha)

    echo "commit $SHA is the head of branch $BRANCH from $REPO"
}

function fetch_and_verify {
    sha256sum --status -c "$1.sha256"
    if [ $? -eq 0 ]; then
        echo "latest $1 present"
    else
        echo "latest $1 is not present, or it is corrupted"
        echo "fetching latest $1"
        curl -OL $PACKAGE_URL
        sha256sum --status -c "$1.sha256"
    fi

    # abort script if we can't successfully retrieve package
    if [ $? -ne 0 ]; then
        echo "could not fetch $1"
        exit $?
    fi
}

pushd /opt

ARTIFACT_URL="https://buildomat.eng.oxide.computer/public/file"

banner xde
REPO='oxidecomputer/os-build'
get_current_branch
PACKAGE_BASE_URL="$ARTIFACT_URL/$REPO/xde/$SHA"
PACKAGE_URL="$PACKAGE_BASE_URL/repo.p5p"
PACKAGE_SHA_URL="$PACKAGE_BASE_URL/repo.p5p.sha256"
curl -L $PACKAGE_SHA_URL | sed 's/\/work\///' > repo.p5p.sha256
fetch_and_verify repo.p5p
# cp instead of mv to prevent re-fetching due to missing file
cp repo.p5p xde.p5p

banner maghemite
REPO='oxidecomputer/maghemite'
get_current_branch
PACKAGE_BASE_URL="$ARTIFACT_URL/$REPO/repo/$SHA"
PACKAGE_URL="$PACKAGE_BASE_URL/mg.p5p"
PACKAGE_SHA_URL="$PACKAGE_BASE_URL/mg.p5p.sha256"
curl -L $PACKAGE_SHA_URL | sed 's/\/out\///' > mg.p5p.sha256
fetch_and_verify mg.p5p

banner opte
REPO='oxidecomputer/opte'
get_current_branch
PACKAGE_BASE_URL="$ARTIFACT_URL/$REPO/repo/$SHA"
PACKAGE_URL="$PACKAGE_BASE_URL/opte.p5p"
PACKAGE_SHA_URL="$PACKAGE_BASE_URL/opte.p5p.sha256"
curl -L $PACKAGE_SHA_URL | sed 's/\/out\///' > opte.p5p.sha256
fetch_and_verify opte.p5p

popd

pushd templates/files
cp /opt/xde.p5p .
cp /opt/mg.p5p .
cp /opt/opte.p5p .

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FWVH16QWB4FCKHNDADG2F8ZN/FmPrmgdSkn44eowjPWFoqikXynga4oJYhHcoBAwjB8E531tv/01FWVH1E7GXY0TRVZYGT7GJ789/01FWVHADFJEW082REBMJMJDC5R/p9kp
