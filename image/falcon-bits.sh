#!/bin/bash

pushd templates/files

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GBNATSKDE01G1K389NNCE9TT/LAv0ABhVuxOcDfLTwYVcb58WO6UpvDKISnzJSFb4HdzeN3WA/01GBNAV15R3SDFJGS495NW00DT/01GBNB3RP5YT2AQ9DH1CAHTVG2/p9kp
