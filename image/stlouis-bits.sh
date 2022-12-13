#!/bin/bash

pushd /opt

# get the stlouis onu p5p archive from oxidecomputer/os-build ci
echo "fetching stlouis onu archive"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GM3VH03DW8RVV7GBWQK6ZBHP/A08P7kn1WfARQbmnGiJpkiBtpvGDskDRX7JEPccQgUGPZUx8/01GM3VH8YBWRQZSBC76M90NG8P/01GM46RDKR46P0TKM03QA0W1BD/repo.p5p
mv repo.p5p stlouis.p5p

popd

pushd templates/files
cp /opt/stlouis.p5p .

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GBNATSKDE01G1K389NNCE9TT/LAv0ABhVuxOcDfLTwYVcb58WO6UpvDKISnzJSFb4HdzeN3WA/01GBNAV15R3SDFJGS495NW00DT/01GBNB3RP5YT2AQ9DH1CAHTVG2/p9kp
