#!/bin/bash

VERBOSE=${VERBOSE:="false"}
MAKE_SIGNATURE_CONFIGMAP=${MAKE_SIGNATURE_CONFIGMAP:="false"}
if [[ "${VERBOSE}" == "true" ]]; then set -x; fi

MIRROR_ENGINE=${MIRROR_ENGINE:="oc"} # oc or oc-mirror

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

AUTHFILE=""
AUTHFILE_PARAM=""
if [[ "${WORKSPACES_AUTHSECRET_BOUND}" == "true" ]]; then
    if [[ -f ${WORKSPACES_AUTHSECRET_PATH}/auth.json ]]; then AUTHFILE="auth.json"; fi
    if [[ -f ${WORKSPACES_AUTHSECRET_PATH}/.dockerconfigjson ]]; then AUTHFILE=".dockerconfigjson"; fi
    if [[ ! -z "${AUTHFILE}" ]]; then
        echo "> Setting credentials ..."
        cp ${WORKSPACES_AUTHSECRET_PATH}/${AUTHFILE} $HOME/.config/containers/auth.json
        cp $HOME/.config/containers/auth.json $TEKTON_HOME/.config/containers/auth.json
        AUTHFILE_PARAM="--authfile $HOME/.config/containers/auth.json"
        REGISTRY_AUTH_FILE="$HOME/.config/containers/auth.json"
        AUTH_FILE="$HOME/.config/containers/auth.json"
    fi
fi

if [[ "${WORKSPACES_SAVEPATH_BOUND}" == "true" ]]; then export TARGET_SAVE_PATH="${WORKSPACES_SAVEPATH_PATH}"; fi

echo "Set Env:"
env
echo ""
echo ""

if [ "${MIRROR_ENGINE}" == "oc" ]; then
    /mirror-release.sh
else
    /oc-mirror.sh
fi

if [[ "${MAKE_SIGNATURE_CONFIGMAP}" == "true" ]]; then
    /make-ocp-release-signature.sh ${OCP_RELEASE}
fi