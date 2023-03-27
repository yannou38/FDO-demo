#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions and global variables intended to make
# file management easier within this application's scripts.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "yamlparse.sh"

# These are helper variables to quickly identify where things will be stored
# These variables are used globally throughout this application's scripts
WEB_ROOT="$(pwd)/data/usr/share/nginx/html"
WEB_FILES="${WEB_ROOT}/files"
WEB_PROFILE="${WEB_ROOT}/profile"
TFTP_ROOT="$(pwd)/data/srv/tftp"
TFTP_IMAGES="${TFTP_ROOT}/images"

parseConfig() {
    local builderConfig="conf/config.yml"
    if [[ -f ${builderConfig} ]]; then
        # the file exists, go ahead and try to parse it
        # printDatedOkMsg "Found Profile, parsing..."
        logOkMsg "Found builderConfig, parsing..."
        # Parse the config.yml config file
        source "scripts/yamlparse.sh"
        eval $(yamlParse "${builderConfig}" "builder_config_")
        printDatedOkMsg "Loaded config successfully."
        logOkMsg "Loaded config successfully."
    else
        printDatedErrMsg "Can't find configuration in ${builderConfig}"
        logFataErrMsg "Can't find configuration in ${builderConfig}"
        exit 1
    fi
}

# Cleans up backup files that are identical.
# The pattern is defined in copySampleFile, and looks like this:
# someFileName_2019-03-19_11:34:47
cleanDuplicateBackups() {
    local sourceFile=$1
    local targetFile=$2

    # Unbound variable error needs to be temporarily ignored
    set +u
    declare -A fileArray

    # The globstar option allows recursive directory printing
    # when using **
    shopt -s globstar

    for file in **; do
        # If the file does not exist, continue the loop
        [[ -f "${file}" ]] || continue

        # We don't want to aggressively delete everything,
        # so this filters out any files that were matched by **
        # but don't match the backup file naming convention's pattern.
        echo ${file} | grep -q "${targetFile}_*-*-*_*:*:*" || continue

        # Proceed to md5sum
        read checkSum _ < <(md5sum "${file}")
        if ((fileArray[${checkSum}]++)); then
            rm ${file}
            logOkMsg "cleaned up duplicate backup file ${file}"
        fi
    done

    # Unset the globstar option because it could break other stuff.
    shopt -u globstar
    set -u
}

# Will check if the target file already exists, and take a backup if it does
copySampleFile() {
    local sourceFile=$1
    local targetFile=$2

    # Check if the target file exists and take a backup if it does
    if [[ "${SKIP_BACKUPS}" == "false" ]]; then
        if [[ -f "${targetFile}" ]]; then
            local BACKUP_TIME=$(date +"%F_%T")
            local BACKUP_FILE="${targetFile}_${BACKUP_TIME}"
            set +e
            logMsg  "$(cp ${targetFile} ${BACKUP_FILE} 2>&1)"
            set -e
            if [ $? -eq 0 ]; then
                logOkMsg "backed up ${targetFile} to ${BACKUP_FILE}"
            else
                logErrMsg "problem backing up ${targetFile} to ${BACKUP_FILE}"
                exit 1
            fi
        fi
    else
        logMsg "User chose to skip backing up files (was going to copy ${sourceFile} to ${targetFile})"
    fi

    set  +e
    logMsg "$(cp ${sourceFile} ${targetFile} 2>&1)"
    set -e
    if [ $? -eq 0 ]; then
        logOkMsg "copied ${sourceFile} to ${targetFile}"
    else
        logErrMsg "problem copying ${sourceFile} to ${targetFile}"
        exit 1
    fi

    cleanDuplicateBackups ${sourceFile} ${targetFile}
}

# Will look for a given Directory, and create it if it doesn't exist
makeDirectory() {
    local desired=$1
    # make sure that the directory exists
    if [ ! -d ${desired} ]; then
        # the directory doesn't exist, make it
        mkdir -p ${desired}
        if [ $? -ne 0 ]; then
            # there was a problem creating the directory
            printDatedErrMsg "problem creating '${desired}'"
            logErrMsg "problem creating '${desired}'"
            exit 1
        else
            logOkMsg "made ${desired}"
        fi
    else
        logOkMsg "found '${desired}'"
    fi
}

downloadPrivateDockerImage() {
    local registry=$1
    local username=$2
    local password=$3
    local sourceName=$4
    local targetName=$5
    local destinationFile=$6
    local dockerAlreadyLoggedIn=$7  # Default is empty; if anything else, it will not log in

    # make sure the destinationDirectory exists
    makeDirectory $(dirname "${destinationFile}")

    # Note if we have the image already
    docker inspect ${targetName} >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        # we already have the image so skip it
        logMsg "Desired image ${targetName} exists${T_RESET}"
        printMsg "${T_OK_ICON} Desired image ${targetName} exists${T_RESET}"
    fi

    # check if dockerAlreadyLoggedIn is set
    # This is used for custom logins to a Docker registry,
    # for example, the output of:
    # aws ecr get-login --registry-id xxxxxxxx | sed "s/\-e\ none//g"
    if [[ -z "${dockerAlreadyLoggedIn}" ]]; then
        # login to the registry
        # printMsg "${T_INFO_ICON} ${C_GRAY}Login to registry ${registry}..."
        logMsg "Login to registry ${registry}..."
        # this is potentially a long running process, show the spinner
        run "Login to registry ${registry}..." \
            "docker login -u ${username} -p ${password} ${registry}" \
            ${LOG_FILE}
    fi

    if [ $? -eq 0 ]; then
        # pull the image
        printMsg "${T_INFO_ICON} ${C_GRAY}Logged in to registry, pulling image... ${T_RESET}"
        logMsg "Logged in to registry, pulling image.. ${sourceName}..."
        # this is potentially a long running process, show the spinner
        run "Downloading ${registry}/${sourceName}" \
            "docker pull ${registry}/${sourceName}" \
            ${LOG_FILE}

        if [ $? -eq 0 ]; then
            # re-tag the image with the given target name
            logMsg "Pulled image, re-tag and save as ${targetName}..."

            # this is potentially a long running process, show the spinner
            run "Pulled image, re-tag and save as ${targetName}..." \
                "docker tag ${registry}/${sourceName} ${targetName} >/dev/null 2>&1 && \
                docker save ${targetName} | gzip >${destinationFile} && \
                printMsg "${T_OK_ICON} Success save ${sourceName} as ${targetName} in ${destinationFile} ${T_RESET}" && \
                logMsg "Success save ${sourceName} as ${targetName} and put in ${destinationFile}" " \
                ${LOG_FILE}
        else
            printDatedErrMsg "Problem pulling ${sourceName} from registry ${registry}"
            logMsg "ERROR Problem pulling ${sourceName} from registry ${registry}"
            exit 1
        fi
    else
        printDatedErrMsg "Problem on login to registry ${registry}"
        logMsg "ERROR Problem on login to registry ${registry}"
        exit 1
    fi
}

downloadPublicDockerImage() {
    local sourceName=$1
    local targetName=$2
    local destinationFile=$3

    # make sure the destinationDirectory exists
    makeDirectory $(dirname "${destinationFile}")

    # Note if we have the image already
    docker inspect ${targetName} >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        # we already have the image so skip it
        logMsg "Desired image ${targetName} exists${T_RESET}"
        printMsg "${T_OK_ICON} Desired image ${targetName} exists${T_RESET}"
    fi

    # pull the image
    # this is potentially a long running process, show the spinner
    run "Downloading ${sourceName}" \
        "docker pull ${sourceName}" \
        ${LOG_FILE}

    if [ $? -eq 0 ]; then
        # re-tag the image with the given target name
        logMsg "Pulled image, re-tag and save as ${targetName}..."

        # this is potentially a long running process, show the spinner
        run "Pulled image, re-tag and save as ${targetName}..." \
            "docker tag ${sourceName} ${targetName} >/dev/null 2>&1 && \
                docker save ${targetName} | gzip >${destinationFile} && \
                printMsg "${T_OK_ICON} Success save ${sourceName} as ${targetName} in ${destinationFile} ${T_RESET}" && \
                logMsg "Success save ${sourceName} as ${targetName} and put in ${destinationFile}" " \
            ${LOG_FILE}
    else
        printDatedErrMsg "Problem pulling ${sourceName}"
        logMsg "ERROR Problem pulling ${sourceName}"
        exit 1
    fi
}

downloadBaseOSFile() {
    local message=$1
    local url=$2
    local profileName=$3
    local filename=$4
    local target_dir="/srv/tftp/images/${profileName}"

    run "${message}" \
        "docker run --rm ${DOCKER_RUN_ARGS} -v ${TFTP_IMAGES}/${profileName}:/tmp/files -w /tmp/files builder-wget wget ${url} -c -O ${filename}" \
        ${LOG_FILE}
}

downloadPublicFile() {
    local message=$1
    local source=$2
    local directory=$3
    local fileName=$4
    local token=$5

    if [[ -z "${token}" || ${token} == "None" ]]; then
        # If the token is not given, don't supply any token headers
        run "${message}" \
            "docker run --rm ${DOCKER_RUN_ARGS} -v ${directory}:/tmp/files -w /tmp/files builder-wget wget ${source} -c -O ${fileName}" \
            ${LOG_FILE}
    else
        # The token is defined, so supply the token headers
        run "${message}" \
            "docker run --rm ${DOCKER_RUN_ARGS} -v ${directory}:/tmp/files -w /tmp/files builder-wget wget --header 'Authorization: token ${token}' ${source} -c -O ${fileName}" \
            ${LOG_FILE}
    fi
}

downloadS3File() {
    local message=$1
    local region=$2
    local accessKey=$3
    local secretKey=$4
    local bucket=$5
    local key=$6 # aka object
    local directory=$7
    local fileName=$8

    local workingdir=$(pwd)

    AWS_DEFAULT_REGION=${region} \
    AWS_ACCESS_KEY_ID=${accessKey} \
    AWS_SECRET_ACCESS_KEY=${secretKey} \
    run "${message}" \
        "docker run --rm ${DOCKER_RUN_ARGS} --env AWS_ACCESS_KEY_ID=${accessKey} --env AWS_SECRET_ACCESS_KEY=${secretKey} --env AWS_DEFAULT_REGION=${region} -v ${directory}:/tmp/files builder-aws-cli aws s3api get-object --bucket ${bucket} --key ${key} /tmp/files/${fileName}" \
        ${LOG_FILE}
}
