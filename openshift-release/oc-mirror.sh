#!/bin/bash

# Mirror registries must support pushing without a tag (only a shasum)

# Download oc binary
# https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/

# Make a joined container pull secret containing all RH credentials as well as your own
# ./join-auths.sh private-ps.json red-hat-ps.json > ~/.combined-mirror-ps.json

# Path to the pull secret
AUTH_FILE=${AUTH_FILE:="/root/.combined-mirror-ps.json"}

# What OpenShift release to mirror
OCP_CHANNEL=${OCP_CHANNEL:="stable"}
OCP_RELEASE=${OCP_RELEASE:="4.17.16"}
OCP_XY_RELEASE="$(echo $OCP_RELEASE | cut -d. -f1).$(echo $OCP_RELEASE | cut -d. -f2)"
OCP_Z_RELEASE="$(echo $OCP_RELEASE | cut -d. -f3)"

# Operational flags
DRY_RUN=${DRY_RUN:="true"}
EXTRA_OC_ARGS=${EXTRA_OC_ARGS:=""}

MIRROR_METHOD=${MIRROR_METHOD:="direct"} # direct or file
MIRROR_DIRECTION=${MIRROR_DIRECTION:="download"} # download or upload, only used when MIRROR_METHOD=file

# If this is a direct mirror, set the registry and path
LOCAL_REGISTRY=${LOCAL_REGISTRY:="disconn-harbor.d70.kemo.labs"}
LOCAL_REGISTRY_BASE_PATH=${LOCAL_REGISTRY_BASE_PATH:=""}

# No need to change these things - probably
ARCHITECTURE=${ARCHITECTURE:="multi"} # amd64, arm64, multi, s390x, ppc64le
SKIP_TLS_VERIFY=${SKIP_TLS_VERIFY:="false"}
DELETE_EXISTING_PATH=${DELETE_EXISTING_PATH:="true"}
TARGET_SAVE_PATH=${TARGET_SAVE_PATH:="/tmp/mirror/${OCP_RELEASE}"}
PRODUCT_REPO="openshift-release-dev"
RELEASE_NAME="ocp-release"
UPSTREAM_REGISTRY=${UPSTREAM_REGISTRY:="quay.io"}
UPSTREAM_PATH="${PRODUCT_REPO}/${RELEASE_NAME}"
if [ -z "${LOCAL_REGISTRY_BASE_PATH}" ]; then
  LOCAL_REGISTRY_TARGET="${LOCAL_REGISTRY}"
else
  LOCAL_REGISTRY_TARGET="${LOCAL_REGISTRY}/${LOCAL_REGISTRY_BASE_PATH}"
fi

# Check for needed binaries
if [ ! $(which oc) ]; then echo "oc not found!" && exit 1; fi

echo "> Mirroring OpenShift Release..."
echo "> Auth file path: ${AUTH_FILE}"
echo "> Release Version: ${OCP_RELEASE}"
echo "> Architecture: ${ARCHITECTURE}"
echo "> Mirror Method: ${MIRROR_METHOD}"
if [ "${MIRROR_METHOD}" != "direct" ]; then echo "> Mirror Direction: ${MIRROR_DIRECTION}"; fi
echo "> Local Registry Target: ${LOCAL_REGISTRY_TARGET}";
echo "> Save Path: ${TARGET_SAVE_PATH}"
echo "> Dry Run: ${DRY_RUN}"
echo "> Skip TLS Verify: ${SKIP_TLS_VERIFY}"
echo "> XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR}"

# Make the save path directory
if [ "${DELETE_EXISTING_PATH}" == "true" ]; then
  if [ -d "${TARGET_SAVE_PATH}" ]; then
    echo "> Deleting existing path ${TARGET_SAVE_PATH}"
    rm -rf ${TARGET_SAVE_PATH}
  fi
fi
mkdir -p ${TARGET_SAVE_PATH}

# Create the ImageSetConfiguration file
cat <<EOF > ${TARGET_SAVE_PATH}/mirror-config.yaml
---
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  platform:
    graph: false
    kubeVirtContainer: true
    architectures:
      - ${ARCHITECTURE}
    channels:
      - name: ${OCP_CHANNEL}-${OCP_XY_RELEASE}
        minVersion: ${OCP_RELEASE}
        maxVersion: ${OCP_RELEASE}
EOF

cat ${TARGET_SAVE_PATH}/mirror-config.yaml

MIRROR_CMD="oc mirror ${EXTRA_OC_ARGS} -c ${TARGET_SAVE_PATH}/mirror-config.yaml"
if [ ! -z "${AUTH_FILE}" ]; then MIRROR_CMD="${MIRROR_CMD} --authfile ${AUTH_FILE}"; fi
if [ "${SKIP_TLS_VERIFY}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dest-skip-tls --source-skip-tls"; fi
if [ "${DRY_RUN}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dry-run"; fi

if [ "${MIRROR_METHOD}" == "direct" ]; then MIRROR_CMD="${MIRROR_CMD} --workspace file://${TARGET_SAVE_PATH} docker://${LOCAL_REGISTRY_TARGET} --v2"; fi
if [ "${MIRROR_METHOD}" == "file" ]; then
  if [ "${MIRROR_DIRECTION}" == "download" ]; then MIRROR_CMD="${MIRROR_CMD} file://${TARGET_SAVE_PATH} --v2"; fi
  if [ "${MIRROR_DIRECTION}" == "upload" ]; then MIRROR_CMD="${MIRROR_CMD} --from file://${TARGET_SAVE_PATH} docker://${LOCAL_REGISTRY_TARGET} --v2"; fi
fi

echo "> Running: ${MIRROR_CMD}"
$MIRROR_CMD

echo "Created directory structure:"
echo "--------------------------------"
tree ${TARGET_SAVE_PATH}

echo "Cluster resources:"
echo "--------------------------------"
cat ${TARGET_SAVE_PATH}/working-dir/cluster-resources/*
