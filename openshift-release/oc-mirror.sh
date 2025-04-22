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
LOCAL_REGISTRY_PATH_OCP_RELEASE=${LOCAL_REGISTRY_PATH_OCP_RELEASE:="man-mirror/ocp"}

# No need to change these things - probably
ARCHITECTURE=${ARCHITECTURE:="x86_64"} # x86_64, aarch64, s390x, ppc64le
SKIP_TLS_VERIFY=${SKIP_TLS_VERIFY:="false"}
OCP_BASE_REGISTRY_PATH="${LOCAL_REGISTRY}/${LOCAL_REGISTRY_PATH_OCP_RELEASE}"
TARGET_SAVE_PATH=${TARGET_SAVE_PATH:="/tmp/ocp-mirror-${OCP_RELEASE}"} # Only used if MIRROR_METHOD=file
PRODUCT_REPO="openshift-release-dev"
RELEASE_NAME="ocp-release"
UPSTREAM_REGISTRY=${UPSTREAM_REGISTRY:="quay.io"}
UPSTREAM_PATH="${PRODUCT_REPO}/${RELEASE_NAME}"

# Check for needed binaries
if [ ! $(which oc) ]; then echo "oc not found!" && exit 1; fi

echo "> Mirroring OpenShift Release..."
echo "> Auth file path: ${AUTH_FILE}"
echo "> Release Version: ${OCP_RELEASE}"
echo "> Architecture: ${ARCHITECTURE}"
echo "> Mirror Method: ${MIRROR_METHOD}"
if [ "${MIRROR_METHOD}" == "direct" ]; then echo "> Local Registry: ${LOCAL_REGISTRY}"; fi
if [ "${MIRROR_METHOD}" == "file" ]; then echo "> Save Path: ${TARGET_SAVE_PATH}" && echo "> Mirror Direction: ${MIRROR_DIRECTION}"; fi
echo "> Dry Run: ${DRY_RUN}"
echo "> Skip TLS Verify: ${SKIP_TLS_VERIFY}"

# Make the save path directory
mkdir -p ${TARGET_SAVE_PATH}/work-dir

# Create the ImageSetConfiguration file
cat <<EOF > ${TARGET_SAVE_PATH}/mirror-config.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  platform:
    architectures:
      - "${ARCHITECTURE}"
    channels:
      - name: ${OCP_CHANNEL}-${OCP_XY_RELEASE}
        minVersion: ${OCP_RELEASE}
        maxVersion: ${OCP_RELEASE}
EOF

cat ${TARGET_SAVE_PATH}/mirror-config.yaml

MIRROR_CMD="oc mirror ${EXTRA_OC_ARGS} -c ${TARGET_SAVE_PATH}/mirror-config.yaml"
if [ "${MIRROR_METHOD}" == "direct" ]; then MIRROR_CMD="${MIRROR_CMD} --workspace file://${TARGET_SAVE_PATH}/work-dir docker://${OCP_BASE_REGISTRY_PATH} --v2"; fi
if [ "${MIRROR_METHOD}" == "file" ]; then
  if [ "${MIRROR_DIRECTION}" == "download" ]; then MIRROR_CMD="${MIRROR_CMD} file://${TARGET_SAVE_PATH}/work-dir --v2"; fi
  if [ "${MIRROR_DIRECTION}" == "upload" ]; then MIRROR_CMD="${MIRROR_CMD} --from file://${TARGET_SAVE_PATH}/work-dir docker://${OCP_BASE_REGISTRY_PATH} --v2"; fi
fi
if [ "${DRY_RUN}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dry-run"; fi
if [ "${SKIP_TLS_VERIFY}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dest-skip-tls --source-skip-tls"; fi

echo "> Running: ${MIRROR_CMD}"
$MIRROR_CMD
