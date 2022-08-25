#!/bin/bash

pushd /opt

echo "fetching xde onu p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GB9KXTVDJMBWE3MYWJAB5RRT/7oGJCNKC1xNtlAK4FlG2pCOh6k2qbwR4jmr5nqNeogI9VP1f/01GB9KY59DXBCPYA3D86HZWX1D/01GB9YQNZNACFYJT162YHT4BPD/repo.p5p
mv repo.p5p xde.p5p

echo "fetching maghemite p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GAPNJQCDD94YY1Z5S3CKKGZM/9BCSks8CwdgOcobDZuR2piLumE6zUF1DjzlQMdIPYUUdybi8/01GAPNKADWRVR6BQ2BGN9XPE3V/01GAPP6TFPAW5S2K7DRCRTFMH1/mg.p5p

echo "fetching opte p5p"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GASNZZCMBSSGNJ861HYW3VV7/60lblVYQwvxaLk1cAadzZcNbXSsrlpLgJMimKzntyA09gHq2/01GASP08C5P83J2ZC9HWWZVZSX/01GASPC8VZHMWVBG54X80V0KGP/opte.p5p

popd

pushd templates/files
cp /opt/xde.p5p .
cp /opt/mg.p5p .
cp /opt/opte.p5p .

# get the p9kp binary from oxidecomputer/p9fs ci
echo "fetching p9kp"
curl -OL https://buildomat.eng.oxide.computer/wg/0/artefact/01GBARQTZCWBK1CDFCD9CZH0QK/bfi1j8ZkKCN2XaJ8FfnQ7W5CQYWyAk61P8bDiyT5Xi10ttNq/01GBARR2K3RR8G4T56A419EWFB/01GBAS16EZZ7B12DZB45TPR6TC/p9kp
