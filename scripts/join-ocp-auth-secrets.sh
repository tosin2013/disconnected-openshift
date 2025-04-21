#!/bin/bash

# This script will join two OpenShift Secrets together
# It does not join arbitrary OpenShift Secrets, just Pull Secret types
# It is useful for taking a Red Hat Pull Secret JSON file and combining it with your private one for mirroring

NAMESPACE=""
SECRET_NAMES=()
NEW_SECRET_NAME=""
NEW_PULL_SECRET='{"auths": {}}'

function helpText {
  echo "Usage: $0 -n <namespace> -s <secret-name> [-s <other-secret-name>] -o <new-secret-name>"
}

# Check to make sure we have to parameters passed to the script
if [ $# -lt 4 ]; then
  helpText
  exit 1
fi

while getopts "h:n:s:o:" option; do
  case $option in
      h) # display Help
          Help
          exit;;
      n) # Get the namespace
          NAMESPACE="$OPTARG";;
      s) # Get the secret name
          SECRET_NAMES+=("$OPTARG");;
      o) # Get the new secret name
          NEW_SECRET_NAME="$OPTARG";;
      \?) # Invalid option
          echo "Error: Invalid option"
          helpText
          exit;;
      :) # Missing argument
          echo "Error: Option -$OPTARG requires an argument."
          helpText
          exit;;
      *) # Invalid option
          echo "Error: Invalid option"
          helpText
          exit;;
  esac
done

# CHeck to make sure we're logged in
if ! oc whoami > /dev/null 2>&1; then
  echo "Error: You are not logged in to OpenShift"
  exit 1
fi

echo "===== Namespace: $NAMESPACE"
echo "===== Secrets: ${SECRET_NAMES[@]}"
echo "===== New Secret: $NEW_SECRET_NAME"
# Check to make sure we have to parameters passed to the script

for SECRET_NAME in "${SECRET_NAMES[@]}"; do
  # Check to make sure the secret exists
  if ! oc get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Error: Secret $SECRET_NAME does not exist in namespace $NAMESPACE"
    exit 1
  else
    SECRET_TYPE=$(oc get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.type}')
    SECRET_AUTH_DATA=""
    if [ "$SECRET_TYPE" = "kubernetes.io/dockerconfigjson" ]; then
      echo "- Secret $SECRET_NAME is of type kubernetes.io/dockerconfigjson"
      SECRET_AUTH_DATA=$(oc get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d)
    fi
    if [ "$SECRET_TYPE" = "kubernetes.io/dockercfg" ]; then
      echo "- Secret $SECRET_NAME is of type kubernetes.io/.dockercfg"
      SECRET_AUTH_DATA=$(oc get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.\.dockercfg}' | base64 -d)
    fi
    
    FIRST_KEY=$(echo "${SECRET_AUTH_DATA}" | jq -r '. | keys[]' | head -n 1)
    echo "First key found: $FIRST_KEY"

    if [[ "$FIRST_KEY" == "auths" ]]; then
      FORMATTED_PULL_SECRET=${SECRET_AUTH_DATA}
      #NEW_PULL_SECRET=$(jq -s '.[0] * .[1]' <(echo "${NEW_PULL_SECRET}") <(echo "${SECRET_AUTH_DATA}"))
    else
      FORMATTED_PULL_SECRET=$(echo "${SECRET_AUTH_DATA}" | jq -c '{auths: .}')
      #echo "Formatted pull secret: $FORMATTED_PULL_SECRET"
    fi
    NEW_PULL_SECRET=$(jq -s '.[0] * .[1]' <(echo "${NEW_PULL_SECRET}") <(echo "${FORMATTED_PULL_SECRET}"))
  fi
done

# Create the new secret
if oc get secret "$NEW_SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "Secret $NEW_SECRET_NAME already exists in namespace $NAMESPACE"
else
  echo "Creating secret $NEW_SECRET_NAME"
  oc create secret docker-registry "$NEW_SECRET_NAME" \
    --docker-server="https://index.docker.io/v1/" \
    --docker-username="unused" \
    --docker-password="unused" \
    --docker-email="unused" \
    -n "$NAMESPACE"
  echo "Setting the new secret data"
  oc set data secret "$NEW_SECRET_NAME" \
    --from-literal=.dockerconfigjson="$(echo "${NEW_PULL_SECRET}")" \
    -n "$NAMESPACE"
fi