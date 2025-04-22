#!/bin/bash

# This script will take a pull secret stored in OpenShift, extract one of the defined endpoints, and copy it to another, then save the Secret with the updated pull secret data
# Usage: ./copy-pull-secret-endpoint.sh -s <source_secret> -i <input_endpoint> -o <output_endpoint>
# Example: ./copy-pull-secret-endpoint.sh -s disconn-tekton/combined-reg-secret -i quay-quay-quay.apps.endurance-sno.d70.lab.kemo.network -o quay-quay.quay.svc

# Get the input parameters
while getopts ":s:i:o:" opt; do
  case $opt in
    s) source_secret="$OPTARG"
    ;;
    i) input_endpoint="$OPTARG"
    ;;
    o) output_endpoint="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

# Check for input parameters
if [ -z "$source_secret" ] || [ -z "$input_endpoint" ] || [ -z "$output_endpoint" ]; then
  echo "Usage: $0 -s <source_secret_namespace/source_secret_name> -i <input_endpoint> -o <output_endpoint>"
  exit 1
fi

# Split the source secret into namespace and name
IFS='/' read -r source_namespace source_name <<< "$source_secret"

# Check if the source secret exists
oc get secret "$source_name" -n "$source_namespace" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Source secret $source_secret does not exist."
  exit 1
fi

# Detect Secret type
SECRET_TYPE=$(oc get secret "$source_name" -n "$source_namespace" -o jsonpath='{.type}')
SECRET_AUTH_DATA=""

if [ "$SECRET_TYPE" = "kubernetes.io/dockerconfigjson" ]; then
  echo "- Secret $source_name is of type kubernetes.io/dockerconfigjson"
  SECRET_AUTH_DATA=$(oc get secret "$source_name" -n "$source_namespace" -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d)
fi
if [ "$SECRET_TYPE" = "kubernetes.io/dockercfg" ]; then
  echo "- Secret $source_name is of type kubernetes.io/.dockercfg"
  SECRET_AUTH_DATA=$(oc get secret "$source_name" -n "$source_namespace" -o jsonpath='{.data.\.dockercfg}' | base64 -d)
fi

# Validate what kinda auth Secret we have
FIRST_KEY=$(echo "${SECRET_AUTH_DATA}" | jq -r '. | keys[]' | head -n 1)
echo "- First key found: $FIRST_KEY"

if [[ "$FIRST_KEY" == "auths" ]]; then
  CURRENT_ENDPOINT_AUTH=$(echo "${SECRET_AUTH_DATA}" | jq -r '.auths["'${input_endpoint}'"]')
else
  CURRENT_ENDPOINT_AUTH=$(echo "${SECRET_AUTH_DATA}" | jq -r '."'${input_endpoint}'"')
fi

# Make sure the endpoint exists
if [ -z "${CURRENT_ENDPOINT_AUTH}" ] || [ "null" == "${CURRENT_ENDPOINT_AUTH}" ]; then
  echo "Error: Endpoint $input_endpoint does not exist in the source secret."
  exit 1
else
  echo "- Current endpoint ${input_endpoint} found"
fi

# Make sure the target endpoint does not exist
if [[ "$FIRST_KEY" == "auths" ]]; then
  TARGET_ENDPOINT_AUTH=$(echo "${SECRET_AUTH_DATA}" | jq -r '.auths["'${output_endpoint}'"]')
else
  TARGET_ENDPOINT_AUTH=$(echo "${SECRET_AUTH_DATA}" | jq -r '."'${output_endpoint}'"')
fi
if [ ! -z "${TARGET_ENDPOINT_AUTH}" ] && [ "null" != "${TARGET_ENDPOINT_AUTH}" ]; then
  echo "Error: Target endpoint $output_endpoint already exists in the source secret."
  exit 1
else
  echo "- Target endpoint ${output_endpoint} does not exist"
fi

# Create a new variable for the new endpoint
NEW_ENDPOINT_AUTH=$(echo "${CURRENT_ENDPOINT_AUTH}" | jq -c '{auths: {"'${output_endpoint}'": .}}')
#echo "New endpoint auth: $NEW_ENDPOINT_AUTH"

# Combine the new endpoint with the existing pull secret
if [[ "$FIRST_KEY" == "auths" ]]; then
  NEW_PULL_SECRET=$(jq -srMc '.[0] * .[1]' <(echo "${SECRET_AUTH_DATA}") <(echo "${NEW_ENDPOINT_AUTH}"))
else
  # Check this - might need to add vs multiply
  NEW_PULL_SECRET=$(jq -rMcs '.[0] * .[1]' <(echo "${SECRET_AUTH_DATA}") <(echo "${NEW_ENDPOINT_AUTH}"))
fi

# Update the secret with the new pull secret
cat <<EOF | oc apply -f -
{
  "apiVersion": "v1",
  "data": {
    ".dockerconfigjson": "$(echo -n "${NEW_PULL_SECRET}" | base64)"
  },
  "kind": "Secret",
  "metadata": {
    "name": "${source_name}",
    "namespace": "${source_namespace}"
  },
  "type": "${SECRET_TYPE}"
}
EOF