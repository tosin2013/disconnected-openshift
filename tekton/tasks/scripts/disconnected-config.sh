#!/usr/bin/env bash

declare -rx WORKSPACES_CONTAINERCONFIG_PATH="${WORKSPACES_CONTAINERCONFIG_PATH:-}"
declare -rx WORKSPACES_CONTAINERCONFIG_BOUND="${WORKSPACES_CONTAINERCONFIG_BOUND:-}"

declare -rx WORKSPACES_AUTHSECRET_PATH="${WORKSPACES_AUTHSECRET_PATH:-}"
declare -rx WORKSPACES_AUTHSECRET_BOUND="${WORKSPACES_AUTHSECRET_BOUND:-}"

mkdir -p $HOME/.config/containers
mkdir -p $TEKTON_HOME/.config/containers

declare -x NEEDS_FORMATTING="true"
declare -x REGISTRY_CONF=""
declare -x AUTHFILE_PARAM=""
# Set for skopeo-copy-proxy
declare -x SKOPEO_REGISTRIESD_FLAG=""
declare -x SKOPEO_AUTHFILE_FLAG=""

if [[ "${WORKSPACES_CONTAINERCONFIG_BOUND}" == "true" ]]; then
    phase "Setting container configuration ..."

    cp -r ${WORKSPACES_CONTAINERCONFIG_PATH}/* $HOME/.config/containers
    cp -r ${WORKSPACES_CONTAINERCONFIG_PATH}/* $TEKTON_HOME/.config/containers
    if [[ -d "${WORKSPACES_CONTAINERCONFIG_PATH}/registries.conf.d" ]]; then
        export SKOPEO_REGISTRIESD_FLAG="--registries.d ${WORKSPACES_CONTAINERCONFIG_PATH}/registries.conf.d"
    fi
    if [[ -f "${WORKSPACES_CONTAINERCONFIG_PATH}/registries.conf" ]]; then
        REGISTRY_CONF="--registries-conf ${WORKSPACES_CONTAINERCONFIG_PATH}/registries.conf"
    fi
    export DOCKER_CONFIG="$HOME/.config/containers/"

    phase "REGISTRY_CONF: '${REGISTRY_CONF}'"
    phase "SKOPEO_REGISTRIESD_FLAG: '${SKOPEO_REGISTRIESD_FLAG}'"
fi


if [[ "${WORKSPACES_AUTHSECRET_BOUND}" == "true" ]]; then

    # Normal kubernetes.io/dockerconfigjson type Secret
    if [[ -f ${WORKSPACES_AUTHSECRET_PATH}/.dockerconfigjson ]]; then
        phase "Detected .dockerconfigjson ..."
        # Test to see if it's a proper auth file
        PULL_SECRET_PATH="${WORKSPACES_AUTHSECRET_PATH}/.dockerconfigjson"
        AUTH_KEY=$(cat ${WORKSPACES_AUTHSECRET_PATH}/.dockerconfigjson | jq -r '. | keys[]' | head -n 1)
        if [[ "${AUTH_KEY}" == "auths" ]]; then
            NEEDS_FORMATTING="false"
        fi
    fi

    # Legacy kubernetes.io/dockercfg type Secret
    if [[ -f ${WORKSPACES_AUTHSECRET_PATH}/.dockercfg ]]; then
        phase "Detected .dockercfg ..."
        # Test to see if it's a proper auth file
        PULL_SECRET_PATH="${WORKSPACES_AUTHSECRET_PATH}/.dockercfg"
        AUTH_KEY=$(cat ${WORKSPACES_AUTHSECRET_PATH}/.dockercfg | jq -r '. | keys[]' | head -n 1)
        if [[ "${AUTH_KEY}" == "auths" ]]; then
            NEEDS_FORMATTING="false"
        fi
    fi

    # Preformatted Opaque type Secret
    if [[ -f ${WORKSPACES_AUTHSECRET_PATH}/auth.json ]]; then
        PULL_SECRET_PATH="${WORKSPACES_AUTHSECRET_PATH}/auth.json"
        AUTH_KEY=$(cat ${WORKSPACES_AUTHSECRET_PATH}/auth.json | jq -r '. | keys[]' | head -n 1)
        if [[ "${AUTH_KEY}" == "auths" ]]; then
            NEEDS_FORMATTING="false"
        fi
    fi

    # Apply any necessary formatting
    if [[ "${NEEDS_FORMATTING}" == "true" ]]; then
        cat > $HOME/.config/containers/auth.json <<EOF
{"auths": $(cat ${PULL_SECRET_PATH})}
EOF
    else
        cp ${PULL_SECRET_PATH} $HOME/.config/containers/auth.json
    fi

    # Set env vars
    AUTHFILE_PARAM="--authfile $HOME/.config/containers/auth.json"
    REGISTRY_AUTH_FILE="$HOME/.config/containers/auth.json"

    phase "AUTHFILE_PARAM: '${AUTHFILE_PARAM}'"
    phase "REGISTRY_AUTH_FILE: '${REGISTRY_AUTH_FILE}'"

    # Auth injection handling since Skopeo is dumb and can't do root domain auth
    if [ -n "${PARAMS_SOURCE_IMAGE_URL}" ] && [ -n "${PARAMS_DESTINATION_IMAGE_URL}" ]; then
        DEST_DOMAIN=$(echo ${PARAMS_DESTINATION_IMAGE_URL} | sed -e 's|.*://||' -e 's|/.*||')
        DEST_IMAGE_NO_TAG=$(echo ${PARAMS_DESTINATION_IMAGE_URL} | sed -e 's|.*://||' -e 's|/||' -e 's|:.*||' -e 's|@sha256||')
        # Check to see if there is a root domain auth
        AUTH_DOMAIN_CHECK=$(jq -r ".auths[\"${DEST_DOMAIN}\"]" $HOME/.config/containers/auth.json)
        if [ "${AUTH_DOMAIN_CHECK}" != "null" ]; then
            AUTH_DEST_IMAGE_CHECK=$(jq -r ".auths[\"${DEST_IMAGE_NO_TAG}\"]" $HOME/.config/containers/auth.json)
            if [ "${AUTH_DEST_IMAGE_CHECK}" == "null" ]; then
                jq ".auths[\"${DEST_IMAGE_NO_TAG}\"] = .auths[\"${DEST_DOMAIN}\"]" $HOME/.config/containers/auth.json > $HOME/.config/containers/auth.json.tmp
                mv $HOME/.config/containers/auth.json.tmp $HOME/.config/containers/auth.json
            fi
        fi
    fi
fi

export XDG_RUNTIME_DIR="$HOME/.config"
echo "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR}"