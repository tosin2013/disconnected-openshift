#!/bin/bash

# This script downloads the latest OCP binaries for the current platform
# and extracts them into the ./bin directory.

ARCH="x86_64"
OS="linux"

mkdir -p ./bin/tmp
cd ./bin/tmp

wget https://mirror.openshift.com/pub/openshift-v4/${ARCH}/clients/ocp/stable/openshift-client-${OS}.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/${ARCH}/clients/ocp/stable/openshift-install-${OS}.tar.gz

tar zxvf openshift-client-${OS}.tar.gz
tar zxvf openshift-install-${OS}.tar.gz

chmod a+x oc
chmod a+x kubectl
chmod a+x openshift-install

mv oc ../
mv kubectl ../
mv openshift-install ../

cd ..
rm -rf tmp