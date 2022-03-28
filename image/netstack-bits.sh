#!/bin/bash

pushd templates/files

echo "fetching xde onu p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FY9ZM2DC0RARSX9PBDVYWA74/YmkbHoTpnPzZNbjM4jY8u1lQEZ7WxI8OX6DJzPglURYVgCr7/01FY9ZMATQF9M2V816RF9CJRD8/01FYAAMJ4EBFS6RKM0838QAXPR/repo.p5p
mv repo.p5p xde.p5p

echo "fetching maghemite p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FZ4NK1MGDXVBC0ASWCW624RN/tjZxfNlmMHBd7ooARRcnjoOb3iJl35ExIcfUmssHay1eZQXg/01FZ4NK9R5ERQH8ECP067EMM5X/01FZ4P477KWJF9SYC7CMM5FA5Y/maghemite-1.0.80.p5p
mv maghemite-1.0.80.p5p mg.p5p

echo "fetching opte zone p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FZ4W1DK9DX51DCAY84Y2SCM3/LZuz9DYaUSZz6EL9uKmKw7EfdoNV0VQZ5WoKPW5Ut3lYdhOK/01FZ4W1RJWGNAEAJZMSFCR9N10/01FZ4WDT9HF59W6MQGYCA8VW0W/opte-1.0.50.p5p
mv opte-1.0.50.p5p opte.p5p

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01FWVH16QWB4FCKHNDADG2F8ZN/FmPrmgdSkn44eowjPWFoqikXynga4oJYhHcoBAwjB8E531tv/01FWVH1E7GXY0TRVZYGT7GJ789/01FWVHADFJEW082REBMJMJDC5R/p9kp

