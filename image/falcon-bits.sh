#!/bin/bash

pushd /opt

# get the falcon onu p5p archive from oxidecomputer/os-build ci
echo "fetching falcon onu archive"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FWW3YV4SAC4EMH7W2GGV970R/kVJorH8BfiGB9VQ7Ds166vCEKi3cccM6YVjwXlFy2YCaD5nB/01FWW3Z2Q5XZNJYC09J6R4WBHH/01FWWESDSSA3SY4NZEHRTAH6FS/repo.p5p
mv repo.p5p falcon.p5p

popd

pushd templates/files
cp /opt/falcon.p5p .

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FWVH16QWB4FCKHNDADG2F8ZN/FmPrmgdSkn44eowjPWFoqikXynga4oJYhHcoBAwjB8E531tv/01FWVH1E7GXY0TRVZYGT7GJ789/01FWVHADFJEW082REBMJMJDC5R/p9kp
