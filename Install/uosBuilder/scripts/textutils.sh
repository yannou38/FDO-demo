#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

LOG_FILE="builder.log"

C_RED='\e[31m'
C_GREEN='\e[32m'
C_YELLOW='\e[33m'
C_BLUE='\e[34m'
C_MAGENTA='\e[35m'
C_CYAN='\e[36m'
C_WHITE='\e[37m'

C_GRAY='\e[30;1m'
C_L_RED='\e[31;1m'
C_L_GREEN='\e[32;1m'
C_L_YELLOW='\e[33;1m'
C_L_BLUE='\e[34;1m'
C_L_MAGENTA='\e[35;1m'
C_L_CYAN='\e[36;1m'
C_L_WHITE='\e[37;1m'

T_RESET='\e[0m'
T_BOLD='\e[1m'
T_ULINE='\e[4m'

T_ERR="${T_BOLD}\e[31;1m"
T_ERR_ICON="[${T_BOLD}${C_RED}✗${T_RESET}]"

T_OK_ICON="[${T_BOLD}${C_GREEN}✓${T_RESET}]"
T_INFO_ICON="[${T_BOLD}${C_YELLOW}i${T_RESET}]"
T_QST_ICON="${T_BOLD}[?]${T_RESET}"

printMsg() {
    echo -e "${1}" 2>&1
}

printMsgNoNewline() {
    echo -n -e "${1}" 2>&1
}

printDatedMsg() {
    printMsg "${C_BLUE}$(date +"%Y-%m-%d %I:%M:%S")${T_RESET} - ${1}${T_RESET}"
}

printDatedInfoMsg() {
    printMsg "${C_BLUE}$(date +"%Y-%m-%d %I:%M:%S")${T_RESET} - ${T_INFO_ICON} ${1}${T_RESET}"
}

printErrMsg() {
    printMsg "${T_ERR_ICON}${T_ERR} $1 ${T_RESET}"
}

printDatedErrMsg() {
    printMsg "${C_BLUE}$(date +"%Y-%m-%d %I:%M:%S")${T_RESET} - ${T_ERR_ICON}${T_ERR} $1 ${T_RESET}"
}

printOkMsg() {
    printMsg "${T_OK_ICON} $1${T_RESET}"
}

printDatedOkMsg() {
    printMsg "${C_BLUE}$(date +"%Y-%m-%d %I:%M:%S")${T_RESET} - ${T_OK_ICON} $1${T_RESET}"
}

printBanner() {
    local bannerText=$1
    printMsg "\n${T_BOLD}${C_BLUE}${bannerText}${T_RESET}"
}

logMsg() {
    echo "$(date +"%Y-%m-%d %I:%M:%S") ${1}" >>${LOG_FILE}
}

logInfoMsg() {
    echo "$(date +"%Y-%m-%d %I:%M:%S") INFO ${1}" >>${LOG_FILE}
}

logErrMsg() {
    logMsg "ERROR $1"
}

logFataErrMsg() {
    logErrMsg "$1"
    echo -e "${T_ERR}Preview:${T_RESET}" 2>&1
    tail -n 3 ${LOG_FILE} 2>&1
    echo -e "${T_ERR}Please check ${LOG_FILE} for more details.${T_RESET}\n\n" 2>&1
    exit 1
}

logOkMsg() {
    logMsg "OK $1"
}

printAndLogDatedInfoMsg() {
    printDatedInfoMsg "$1"
    logMsg "$1"
}

printAndLogDatedErrMsg() {
    printDatedErrMsg "$1"
    logErrMsg "$1"
}

spinner() {
    local pid="$!"
    local delay=0.08
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep ${pid})" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "${spinstr}" 2>&1
        local spinstr=${temp}${spinstr%"$temp"}
        sleep ${delay}
        printf "\b\b\b\b\b\b" 2>&1
    done
    printf "    \b\b\b\b" 2>&1
}

run() {
    local msg=$1
    local runThis=$2
    local log=$3
    echo -e -n "${C_BLUE}$(date +"%Y-%m-%d %I:%M:%S")${T_RESET} - ${msg}...${T_RESET}" 2>&1
    echo "$(date +"%Y-%m-%d %I:%M:%S") START: Running ${runThis}..." >>${log}
    (eval ${runThis} >>${log} 2>&1) &
    spinner
    wait %1
    exitcode=$?
    if [ ${exitcode} -ne 0 ]; then
        local success=false
    else
        local success=true
    fi
    if [ "${success}" = false ]; then
        echo "$(date +"%Y-%m-%d %I:%M:%S") FAILED: Running ${runThis}..." >>${log}
        echo -e "\n${C_BLUE}$(date +"%Y-%m-%d %I:%M:%S")${T_RESET} -   ${T_ERR_ICON}${T_ERR}FAILED: Running ${runThis}${T_RESET}" 2>&1
        echo -e "${T_ERR}Log Preview:${T_RESET}" 2>&1
        tail -n 3 ${log} 2>&1
        echo -e "${T_ERR}Please check ${log} for more details.${T_RESET}\n\n" 2>&1
        exit 1
    else
        echo "$(date +"%Y-%m-%d %I:%M:%S") SUCCESS: Running ${runThis}..." >>${log}
        echo -e " ${T_OK_ICON} ${C_GREEN}Success${T_RESET}" 2>&1
    fi
}

# Ensures that we can consistently handle blank inputs of the following forms:
# None
# ''
# ""
# Will return either the original value if it is not empty, or an empty value.
validateEmptyInput() {
    local input=$1

    if [[ "${input}" == "None" || "${input}" == "\"\"" || "${input}" == "''" ]]; then
        echo ""
    else
        echo ${input}
    fi
}
