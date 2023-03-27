#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

source "scripts/textutils.sh"

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Build Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-p${T_RESET}, --skip-profile-builds  Skips the execution of profile-specific build.sh scripts"
    printMsg "  ${T_BOLD}-P${T_RESET}, --skip-profiles        Skips syncronizing profiles"
    printMsg "  ${T_BOLD}-f${T_RESET}, --skip-files           Skips syncronizing the files for profiles"
    printMsg "  ${T_BOLD}-s${T_RESET}, --skip-build-uos       Skips building the Utility Operating System (UOS)"
    printMsg "  ${T_BOLD}-S${T_RESET}, --skip-image-builds    Skips building all images and UOS"
    printMsg "  ${T_BOLD}-c${T_RESET}, --clean-uos            will clean the intermediary docker images used during building of UOS"
    printMsg "  ${T_BOLD}-b${T_RESET}, --skip-backups         Skips the creation of backup files inside the data directory when re-running build.sh"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help                 Show this help dialog"
    printMsg ""
    printMsg " Usage: ./build.sh"
    printMsg ""
    exit 0
}

UOS_CLEAN="false"
BUILD_UOS="true"
BUILD_IMAGES="true"
SKIP_FILES="false"
SKIP_BACKUPS="false"
SKIP_PROFILES="false"
SKIP_PROFILE_BUILDS="false"
for var in "$@"; do
    case "${var}" in
        "-c" | "--clean-uos"           )    UOS_CLEAN="true";;
        "-s" | "--skip-build-uos"      )    BUILD_UOS="false";;
        "-S" | "--skip-image-builds"   )    BUILD_IMAGES="false";;
        "-F" | "--skip-files"          )    SKIP_FILES="true";;
        "-b" | "--skip-backups"        )    SKIP_BACKUPS="true";;
        "-p" | "--skip-profile-builds" )    SKIP_PROFILE_BUILDS="true";;
        "-P" | "--skip-profiles"       )    SKIP_PROFILES="true";;
        "-h" | "--help"                )    printHelp;;
    esac
done

source "scripts/fileutils.sh"
source "scripts/bulkfileutils.sh"

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to the builder host build script"


source "scripts/templateutils.sh"

# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='localhost,127.0.0.1'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='localhost,127.0.0.1'"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='localhost,127.0.0.1';"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

echo "args:"
echo $DOCKER_BUILD_ARGS $DOCKER_RUN_ARGS

# Build Utility OS, if desired
if [[ "${BUILD_UOS}" == "true" ]] && [[ "${BUILD_IMAGES}" == "true" ]]; then
    printBanner "Building ${C_GREEN}Utility OS (UOS)..."
    logMsg "Building Utility OS (UOS)..."
    source "scripts/buildUOS.sh"
else
    logMsg "Skipping Build of UOS"
fi

logMsg "Moving Build image to installer dir..."
mkdir ../Edge-Software-Provisioner/data/srv/tftp/images/uos
rm ../Edge-Software-Provisioner/data/srv/tftp/images/uos/*
mv ./data/srv/tftp/images/uos/initrd ../Edge-Software-Provisioner/data/srv/tftp/images/uos/initrd
mv ./data/srv/tftp/images/uos/vmlinuz ../Edge-Software-Provisioner/data/srv/tftp/images/uos/vmlinuz

logMsg "Done !"
