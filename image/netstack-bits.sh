#!/bin/bash

pushd templates/files

echo "fetching xde onu archive"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FY9ZM2DC0RARSX9PBDVYWA74/YmkbHoTpnPzZNbjM4jY8u1lQEZ7WxI8OX6DJzPglURYVgCr7/01FY9ZMATQF9M2V816RF9CJRD8/01FYAAMJ4EBFS6RKM0838QAXPR/repo.p5p
mv repo.p5p xde.p5p

echo "fetching maghemite zone image"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FYZ7028C6D7SMK7SRJ5E6AA6/Y6pH8duoTFXrmjKQTFnw2mNLVOL4zT3E1yxYRbIqEK09UYsm/01FYZ70A79883A0QAQEZBWH5F0/01FYZ7KDFF8QTGAQ2A7Y81RW1Q/mg-ddm.tar.gz
mv mg-ddm.tar.gz /rpool/images/output/

echo "fetching opte zone image"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FYZK0YKPR7WS506654Z8JNMM/MrmtFyFQh6MIAPPbjLIuoCvsLFbX0v0AA0GR6C1Hq45ns0HQ/01FYZK16GW84YFAVAAZQD130PW/01FYZKCSBHXP08K9WSBG7VCMWX/opte.tar.gz
mv opte.tar.gz /rpool/images/output/

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FWVH16QWB4FCKHNDADG2F8ZN/FmPrmgdSkn44eowjPWFoqikXynga4oJYhHcoBAwjB8E531tv/01FWVH1E7GXY0TRVZYGT7GJ789/01FWVHADFJEW082REBMJMJDC5R/p9kp

