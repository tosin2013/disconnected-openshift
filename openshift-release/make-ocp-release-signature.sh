#!/bin/bash

#set -x

OCP_RELEASE="${1}"

# Check if OCP_RELEASE is provided
if [ -z "${OCP_RELEASE}" ]; then
  echo "Usage: $0 <OCP_RELEASE>"
  exit 1
fi

DRY_RUN=${DRY_RUN:="true"}
VERBOSE=${VERBOSE:="false"}
SKIP_TLS_VERIFY=${SKIP_TLS_VERIFY:="false"}
LOOKUP_MODE=${LOOKUP_MODE:="offline"} #online for curl+release, offline for oc/container things
LOCAL_REGISTRY=${LOCAL_REGISTRY:=""} # eg quay.io
LOCAL_REGISTRY_RELEASE_PATH=${LOCAL_REGISTRY_RELEASE_PATH:="openshift/release-images"} # eg openshift-release-dev/ocp-release
ARCHITECTURE=${ARCHITECTURE:="x86_64"}

# Can't remember what this does?
if [[ $OCP_RELEASE =~ "4." ]]; then
  IMAGE="${OCP_RELEASE}-${ARCHITECTURE}"
else
  IMAGE="${OCP_RELEASE}"
fi

CURL_OPTIONS="-s"
OC_OPTIONS=""
if [ "${VERBOSE}" == "true" ]; then
  CURL_OPTIONS="-vvvv"
fi
if [ "${SKIP_TLS_VERIFY}" == "true" ]; then
  CURL_OPTIONS="${CURL_OPTIONS} -k"
  OC_OPTIONS="${OC_OPTIONS} --insecure=true"
fi

echo "=== Creating signature ConfigMap ==="
echo "> DRY RUN: ${DRY_RUN}"
echo "> VERBOSE: ${VERBOSE}"
echo "> SKIP TLS VERIFY: ${SKIP_TLS_VERIFY}"
echo "> OCP RELEASE: ${OCP_RELEASE}"
echo "> ARCHITECTURE: ${ARCHITECTURE}"
echo "> LOOKUP MODE: ${LOOKUP_MODE}"
echo "> LOCAL REGISTRY: ${LOCAL_REGISTRY}"
echo "> LOCAL REGISTRY RELEASE PATH: ${LOCAL_REGISTRY_RELEASE_PATH}"
echo "> ENDPOINT: ${LOCAL_REGISTRY}/${LOCAL_REGISTRY_RELEASE_PATH}"
echo "> IMAGE: ${IMAGE}"

# Get the digest tag from the release info
if [ "${LOOKUP_MODE}" == "online" ]; then
  RELEASE_INFO=$(curl ${CURL_OPTIONS} -H "Accept: text/plain" https://mirror.openshift.com/pub/openshift-v4/${ARCHITECTURE}/clients/ocp/${OCP_RELEASE}/release.txt)
else
  RELEASE_INFO=$(oc adm release info ${OC_OPTIONS} ${LOCAL_REGISTRY}/${LOCAL_REGISTRY_RELEASE_PATH}:${IMAGE})
fi

if [ $? -ne 0 ]; then
  echo "Failed to get release info. Please check the OCP release version."
  exit 1
fi

# Extract the digest tag and shasum
DIGEST_TAG=$(echo -e "${RELEASE_INFO}" | grep 'Digest:' | rev | cut -d' ' -f 1 | rev)
DIGEST_TAG_SHASUM=$(echo "${DIGEST_TAG}" | cut -d':' -f 2)

echo "> DIGEST TAG: $DIGEST_TAG"
echo "> DIGEST TAG SHASUM: $DIGEST_TAG_SHASUM"

# Create a temporary directory
mkdir -p /tmp/ocp-sig-1-${OCP_RELEASE}

# Download the signature file
curl ${CURL_OPTIONS} -o /tmp/ocp-sig-1-${OCP_RELEASE}/signature-1 https://mirror.openshift.com/pub/openshift-v4/signatures/openshift-release-dev/ocp-release/sha256%3D${DIGEST_TAG_SHASUM}/signature-1
if [ $? -ne 0 ]; then
  echo "Failed to download the signature file. Please check the URL."
  exit 1
fi


# Construct the YAML file

LABEL_STR='"release.openshift.io/verification-signatures": "", "source-path": "'${LOCAL_REGISTRY_RELEASE_PATH}'", "release-version": "'${OCP_RELEASE}'", "source-registry": "'${LOCAL_REGISTRY}'", "source-image": "'${IMAGE}'"' # so labels can't have slashes in the key or value
oc create configmap sha256-${DIGEST_TAG_SHASUM} -n openshift-config-managed --from-file=sha256-${DIGEST_TAG_SHASUM}-1=/tmp/ocp-sig-1-${OCP_RELEASE}/signature-1 --dry-run=client -o json > /tmp/ocp-sig-1-${OCP_RELEASE}/init-configmap.json
jq ".metadata.labels |= . + {$LABEL_STR}" /tmp/ocp-sig-1-${OCP_RELEASE}/init-configmap.json > /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.json
#jq ".metadata.annotations |= . + {$ANNOTATION_STR}" /tmp/ocp-sig-1-${OCP_RELEASE}/labeled-configmap.json > /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.json

cat /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.json

oc create --dry-run=client -o yaml -f /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.json > /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.yml

cat /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.yml

if [ "${DRY_RUN}" == "true" ]; then
  echo "DRY RUN: Not applying configmap"
  exit 0
else
  oc apply -f /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.yml
  #oc label --overwrite configmap sha256-${DIGEST_TAG_SHASUM} -n openshift-config-managed release-version="${OCP_RELEASE}" source-registry="${LOCAL_REGISTRY}" source-image="${IMAGE}"
fi

# Clean up
rm -rf /tmp/ocp-sig-1-${OCP_RELEASE}