#!/bin/bash

pushd /opt

echo "fetching xde onu p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FY9ZM2DC0RARSX9PBDVYWA74/YmkbHoTpnPzZNbjM4jY8u1lQEZ7WxI8OX6DJzPglURYVgCr7/01FY9ZMATQF9M2V816RF9CJRD8/01FYAAMJ4EBFS6RKM0838QAXPR/repo.p5p
mv repo.p5p xde.p5p

echo "fetching maghemite p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01G0JAFMZ0VGR9PV1E3H4RB3PR/HOj4QkPA7jBtWP4MtbXf4d7E4mVKKX7Mp9B4R60iU4gqqbE8/01G0JAFX0CVQ97DRA0DEW48D62/01G0JB0YN94HH4GKAAQPRERWMY/maghemite-0.1.110.p5p
mv maghemite-0.1.110.p5p mg.p5p

echo "fetching opte p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01G0DM53XR4E008D6ET5T8DXP6/wBWo0Jsg1AG19toIyAY23xAWhzmuNKmAsF6tL18ypZODNuHK/01G0DM5DMFN9292PRSGF0EBATG/01G0DMGDKHGEJMKPKZPWV06MCZ/opte-0.1.56.p5p
mv opte-0.1.56.p5p opte.p5p

popd

pushd templates/files
cp /opt/xde.p5p .
cp /opt/mg.p5p .
cp /opt/opte.p5p .

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FWVH16QWB4FCKHNDADG2F8ZN/FmPrmgdSkn44eowjPWFoqikXynga4oJYhHcoBAwjB8E531tv/01FWVH1E7GXY0TRVZYGT7GJ789/01FWVHADFJEW082REBMJMJDC5R/p9kp

