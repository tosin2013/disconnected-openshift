#!/bin/bash

# This script is used to mirror operators and indexes from one registry to another.
# It's basically just an oc-mirror wrapper

# Usage: ./mirror-operators.sh <source-catalog-index> <target-catalog-index> list-of operators to-index

# Example: ./mirror-operators.sh registry.redhat.io/redhat/redhat-operator-index:v4.18 \
#  man-mirror.jfrog.lab.kemo.network/operators \
#  aws-load-balancer-operator 3scale-operator node-observability-operator

# Path to the pull secret
AUTH_FILE=${AUTH_FILE:="/root/.combined-mirror-ps.json"}

# Operational flags
DRY_RUN=${DRY_RUN:="true"}
EXTRA_OC_ARGS=${EXTRA_OC_ARGS:=""}

MIRROR_METHOD=${MIRROR_METHOD:="direct"} # direct or file
MIRROR_DIRECTION=${MIRROR_DIRECTION:="download"} # download or upload, only used when MIRROR_METHOD=file

# No need to change these things - probably
SKIP_TLS_VERIFY=${SKIP_TLS_VERIFY:="false"}
TARGET_SAVE_PATH=${TARGET_SAVE_PATH:="/tmp/mirror"}

# Get the source and target catalog indexes from the command line
SOURCE_CATALOG_INDEX=$1
TARGET_CATALOG_INDEX=$2

# Get the list of operators to index from the remaining arguments from the command line
shift 2
OPERATOR_LIST=("$@")

# Check if the source and target catalog indexes are provided
if [ -z "$SOURCE_CATALOG_INDEX" ] || [ -z "$TARGET_CATALOG_INDEX" ]; then
  echo "Usage: $0 <source-catalog-index> <target-catalog-index> <operator1> <operator2> ..."
  exit 1
fi
# Check if the operator list is provided
if [ ${#OPERATOR_LIST[@]} -eq 0 ]; then
  echo "Usage: $0 <source-catalog-index> <target-catalog-index> <operator1> <operator2> ..."
  exit 1
fi
# Check if the required binaries are installed
if [ ! $(which oc) ]; then echo "oc not found!" && exit 1; fi

# if ! command -v oc-mirror &> /dev/null; then
#   echo "oc-mirror could not be found. Please install it and try again."
#   exit 1
# fi

echo "> ====== Mirroring Operators..."
echo "> Source Catalog Index: ${SOURCE_CATALOG_INDEX}"
echo "> Target Catalog Index: ${TARGET_CATALOG_INDEX}"
echo "> Operators to Index: ${OPERATOR_LIST[@]}"

# Create a temporary directory for the mirror process
mkdir -p ${TARGET_SAVE_PATH}

# Create the ImageSetConfiguration file
cat <<EOF > ${TARGET_SAVE_PATH}/mirror-config.yaml
---
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  operators:
    - catalog: ${SOURCE_CATALOG_INDEX}
      packages:
EOF
for OPERATOR in "${OPERATOR_LIST[@]}"; do
  echo "        - name: ${OPERATOR}" >> ${TARGET_SAVE_PATH}/mirror-config.yaml
done

echo "> ====== Generated ISC:"
cat ${TARGET_SAVE_PATH}/mirror-config.yaml

MIRROR_CMD="oc mirror ${EXTRA_OC_ARGS} -c ${TARGET_SAVE_PATH}/mirror-config.yaml"
if [ ! -z "${AUTH_FILE}" ]; then MIRROR_CMD="${MIRROR_CMD} --authfile ${AUTH_FILE}"; fi
if [ "${SKIP_TLS_VERIFY}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dest-skip-tls --source-skip-tls"; fi
if [ "${DRY_RUN}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dry-run"; fi

if [ "${MIRROR_METHOD}" == "direct" ]; then MIRROR_CMD="${MIRROR_CMD} --workspace file://${TARGET_SAVE_PATH} docker://${TARGET_CATALOG_INDEX} --v2"; fi
if [ "${MIRROR_METHOD}" == "file" ]; then
  if [ "${MIRROR_DIRECTION}" == "download" ]; then MIRROR_CMD="${MIRROR_CMD} file://${TARGET_SAVE_PATH} --v2"; fi
  if [ "${MIRROR_DIRECTION}" == "upload" ]; then MIRROR_CMD="${MIRROR_CMD} --from file://${TARGET_SAVE_PATH} docker://${TARGET_CATALOG_INDEX} --v2"; fi
fi

echo "> Running: ${MIRROR_CMD}"
$MIRROR_CMD

echo "Created directory structure:"
echo "--------------------------------"
tree ${TARGET_SAVE_PATH}

echo "Cluster resources:"
echo "--------------------------------"
cat ${TARGET_SAVE_PATH}/working-dir/cluster-resources/*