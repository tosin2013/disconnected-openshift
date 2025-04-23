#!/bin/bash

#set -x

OCP_RELEASE="${1}"

# Check if OCP_RELEASE is provided
if [ -z "${OCP_RELEASE}" ]; then
  echo "Usage: $0 <OCP_RELEASE>"
  exit 1
fi

DRY_RUN=${DRY_RUN:="true"}
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

echo "=== Creating signature ConfigMap ==="
echo "> OCP RELEASE: ${OCP_RELEASE}"
echo "> ARCHITECTURE: ${ARCHITECTURE}"
echo "> ENDPOINT: ${LOCAL_REGISTRY}/${LOCAL_REGISTRY_RELEASE_PATH}"
echo "> IMAGE: ${IMAGE}"

# Get the digest tag from the release info
if [ "${LOOKUP_MODE}" == "online" ]; then
  if [ "${SKIP_TLS_VERIFY}" == "true" ]; then
    RELEASE_INFO=$(curl -sk -H "Accept: text/plain" https://mirror.openshift.com/pub/openshift-v4/${ARCHITECTURE}/clients/ocp/${OCP_RELEASE}/release.txt)
  else
    RELEASE_INFO=$(curl -s -H "Accept: text/plain" https://mirror.openshift.com/pub/openshift-v4/${ARCHITECTURE}/clients/ocp/${OCP_RELEASE}/release.txt)
  fi
else
  if [ "${SKIP_TLS_VERIFY}" == "true" ]; then
    RELEASE_INFO=$(oc adm release info --insecure=true ${LOCAL_REGISTRY}/${LOCAL_REGISTRY_RELEASE_PATH}:${IMAGE})
  else
    RELEASE_INFO=$(oc adm release info ${LOCAL_REGISTRY}/${LOCAL_REGISTRY_RELEASE_PATH}:${IMAGE})
  fi
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
if [ "${SKIP_TLS_VERIFY}" == "true" ]; then
  curl -sk -o /tmp/ocp-sig-1-${OCP_RELEASE}/signature-1 https://mirror.openshift.com/pub/openshift-v4/signatures/openshift-release-dev/ocp-release/sha256%3D${DIGEST_TAG_SHASUM}/signature-1
else
  curl -s -o /tmp/ocp-sig-1-${OCP_RELEASE}/signature-1 https://mirror.openshift.com/pub/openshift-v4/signatures/openshift-release-dev/ocp-release/sha256%3D${DIGEST_TAG_SHASUM}/signature-1
fi

if [ $? -ne 0 ]; then
  echo "Failed to download the signature file. Please check the URL."
  exit 1
fi


# Construct the YAML file
oc create configmap sha256-${DIGEST_TAG_SHASUM} -n openshift-config-managed --from-file=sha256-${DIGEST_TAG_SHASUM}-1=/tmp/ocp-sig-1-${OCP_RELEASE}/signature-1 --dry-run=client -o yaml | yq -rM '.metadata += {"labels": {"release.openshift.io/verification-signatures": ""}}' > /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.yml

if [ "${DRY_RUN}" == "true" ]; then
  echo "DRY RUN: Not applying configmap"
  cat /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.yml
  exit 0
else
  oc apply -f /tmp/ocp-sig-1-${OCP_RELEASE}/configmap.yml
fi

# Clean up
rm -rf /tmp/ocp-sig-1-${OCP_RELEASE}