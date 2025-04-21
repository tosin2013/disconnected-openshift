#!/bin/bash

# This script will simply copy the secret from the source to the destination
# Usage: ./copy-secret.sh -i <input_secret_namespace/input_secret_name> -o <output_secret_namespace/output_secret_name>
# Example: ./copy-secret.sh -i default/my-secret -o default/my-secret-copy

# Get the input parameters
while getopts ":i:o:" opt; do
  case $opt in
    i) input_secret="$OPTARG"
    ;;
    o) output_secret="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

# Check for input parameters
if [ -z "$input_secret" ] || [ -z "$output_secret" ]; then
  echo "Usage: $0 -i <input_secret_namespace/input_secret_name> -o <output_secret_namespace/output_secret_name>"
  exit 1
fi

# Split the input and output secret into namespace and name
IFS='/' read -r input_namespace input_name <<< "$input_secret"
IFS='/' read -r output_namespace output_name <<< "$output_secret"

# Check if the input secret exists
oc get secret "$input_name" -n "$input_namespace" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Input secret $input_secret does not exist."
  exit 1
fi

# Check if the output secret already exists
oc get secret "$output_name" -n "$output_namespace" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Output secret $output_secret already exists. Please delete it first."
  exit 1
fi

# Create the output secret by copying the input secret
SECRET_TYPE=$(oc get secret "$input_name" -n "$input_namespace" -o jsonpath='{.type}')

cat <<EOF | oc create -f -
{
  "apiVersion": "v1",
  "data": $(oc get secret "$input_name" -n "$input_namespace" -o jsonpath='{.data}'),
  "kind": "Secret",
  "metadata": {
    "name": "${output_name}",
    "namespace": "${output_namespace}"
  },
  "type": "${SECRET_TYPE}"
}
EOF
