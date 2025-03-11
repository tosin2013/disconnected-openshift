#!/bin/bash

REGISTRY_CONF=""
if [[ "${WORKSPACES_CONTAINERCONFIG_BOUND}" == "true" ]]; then
    if [[ -f "${WORKSPACES_CONTAINERCONFIG_PATH}/registries.conf" ]]; then
        REGISTRY_CONF="--registries-conf ${WORKSPACES_CONTAINERCONFIG_PATH}/registries.conf"
    fi
    echo "> Setting container configuration ..."
    mkdir -p $HOME/.config/containers
    mkdir -p $TEKTON_HOME/.config/containers
    cp -r ${WORKSPACES_CONTAINERCONFIG_PATH}/* $HOME/.config/containers
    cp -r ${WORKSPACES_CONTAINERCONFIG_PATH}/* $TEKTON_HOME/.config/containers
    export DOCKER_CONFIG="$HOME/.config/containers/"
fi

AUTHFILE_PARAM=""
if [[ "${WORKSPACES_AUTHSECRET_BOUND}" == "true" ]]; then
    if [[ -f ${WORKSPACES_AUTHSECRET_PATH}/auth.json ]]; then
        echo "> Setting credentials ..."
        cat >> $HOME/.config/containers/auth.json <<EOF
{"auths": $(cat ${WORKSPACES_AUTHSECRET_PATH}/auth.json)}
EOF
        cp $HOME/.config/containers/auth.json $TEKTON_HOME/.config/containers/auth.json
        AUTHFILE_PARAM="--authfile $HOME/.config/containers/auth.json"
        REGISTRY_AUTH_FILE="$HOME/.config/containers/auth.json"
        AUTH_FILE="$HOME/.config/containers/auth.json"
    fi
fi

if [[ "${WORKSPACES_SAVEPATH_BOUND}" == "true" ]]; then export TARGET_SAVE_PATH="${WORKSPACES_SAVEPATH_PATH}"; fi

/mirror-release.sh