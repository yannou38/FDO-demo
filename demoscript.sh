#!/bin/bash
C_RED='\e[31m'
C_GREEN='\e[32m'
C_YELLOW='\e[33m'
C_BLUE='\e[34m'

T_RESET='\e[0m'
T_BOLD='\e[1m'

T_ERR="${T_BOLD}\e[31;1m"
T_ERR_ICON="[${T_BOLD}${C_RED}✗${T_RESET}]"

T_OK_ICON="${T_BOLD}${C_GREEN}[✓]${T_RESET}"
T_INFO_ICON="[${T_BOLD}${C_YELLOW}i${T_RESET}]"
T_QST_ICON="${T_BOLD}[?]${T_RESET}"

printMsg() {
    echo -e "${1}" 2>&1
}

printBanner() {
    local bannerText=$1
    printMsg "\n${T_BOLD}${C_BLUE}${bannerText}${T_RESET}"
}

printHelp() {
    printBanner "Demo Script"
    printMsg " You can specify the following arguments:"
    printMsg "  ${T_BOLD}-d${T_RESET},  --di         Create the device VM, will get OS via PXE then perform DI."
    printMsg "  ${T_BOLD}-o${T_RESET},  --owner      Generate a voucher and register the owner to the rv server."
    printMsg "  ${T_BOLD}-r${T_RESET},  --resale     Perform a resale of the voucher before registering the owner to the rv server. can't be used without -o."
    printMsg "  ${T_BOLD}-n${T_RESET},  --network    Change network of the device."
    printMsg "  ${T_BOLD}-t${T_RESET},  --to12       Start device, who will execute TO1 and TO2."
    printMsg "  ${T_BOLD}-f${T_RESET},  --full       All of the above."
    printMsg "  ${T_BOLD}-p${T_RESET},  --preconfig  Configure the various services with rdv info."
    printMsg "  ${T_BOLD}-h${T_RESET},  --help       Show this help dialog."
    printMsg " This demo will:"
    printMsg " - (d)  Create a new 'device' VM on a factory network (comprising a PXE server, manufacturer, factory owner&reseller"
    printMsg " - (d)  Automatically install a minimal OS then run DI"
    printMsg " - (o)  Perform the steps to generate an ownership voucher"
    printMsg " - (r) Resell it to a 'client' owner"
    printMsg " - (o)  Perform TO0 with the client owner and rv server on the client network"
    printMsg " - (n)  Switch the device to the client network"
    printMsg " - (t)  Perform TO1 and TO2"
    printMsg " - (t)  Install the final OS and Edge Framework Agent"
    printMsg " - (t)  Register the device in the Edge Framework"
    exit 0
}

STEP_PRECONFIG="false"
STEP_CREATE_DI="false"
STEP_VOUCHER_REGISTER="false"
STEP_VOUCHER_RESALE="false"
STEP_CHANGENETWORK="false"
STEP_TO1_2="false"

if [ $# -eq 0 ]; then
    printHelp
fi

for var in "$@"; do
    case "${var}" in
        "-d" | "--di"       )  STEP_CREATE_DI="true";;
        "-o" | "--owner"    )  STEP_VOUCHER_REGISTER="true";;
        "-r" | "--resale"   )  STEP_VOUCHER_RESALE="true";;
        "-n" | "--network"  )  STEP_CHANGENETWORK="true";;
        "-t" | "--to12"     )  STEP_TO1_2="true";;
        "-f" | "--full"     )  STEP_PRECONFIG="true";STEP_CREATE_DI="true";STEP_VOUCHER_REGISTER="true";STEP_VOUCHER_RESALE="true";STEP_CHANGENETWORK="true";STEP_TO1_2="true";;
        "-p" | "--preconfig")  STEP_PRECONFIG="true";;
        "-h" | "--help"     )  printHelp;;
    esac
done

DEVICE_VM="demo_device_vm"
FACTORYOWNER_IP=$(virsh domifaddr demo_factory_owner_vm | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
CLIENTOWNER_IP=$(virsh domifaddr demo_client_owner_vm | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
MANUFACTURER_IP=$(virsh domifaddr demo_manufacturer_vm | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")

##################################################################
## This is the IP where nexus should be found, and is outside of this demo. Change this as needed.
NEXUS_IPPORT="XX.XX.XX.XX:YYYY"
##################################################################

FACTORYOWNER_CREDS="apiUser:"
CLIENTOWNER_CREDS="apiUser:"
MANUFACTURER_CREDS="apiUser:"
RESELLER_CREDS="apiUser:"

if [[ "${STEP_PRECONFIG}" == "true" ]]; then
    # this should probably be always done? with a check to see if conf is okay, but hard to do it properly
    printBanner "Configuration of the various services before demo"
    if [[ "${STEP_VOUCHER_RESALE}" == "true" ]]; then
	curl -D - --digest -u ${CLIENTOWNER_CREDS} -L -X POST "http://${CLIENTOWNER_IP}:8042/api/v1/owner/redirect" -H 'Content-Type: text/plain' --data-raw "[[\"$CLIENTOWNER_IP\",\"stub-dns.client\",8042,3]]"
	curl -D - --digest -u ${CLIENTOWNER_CREDS} -L -X POST "http://${CLIENTOWNER_IP}:8042/api/v1/owner/svi" -H 'Content-Type: text/plain' --data-raw '[{"filedesc" : "/persist/installOS.sh", "resource": "http://'"${NEXUS_IPPORT}"'/repository/raw/install_OS.sh"}]'
    else
	curl -D - --digest -u ${FACTORYOWNER_CREDS} -L -X POST "http://${FACTORYOWNER_IP}:8042/api/v1/owner/redirect" -H 'Content-Type: text/plain' --data-raw "[[\"$FACTORYOWNER_IP\",\"stub-dns.factory\",8042,3]]"
	curl -D - --digest -u ${FACTORYOWNER_CREDS} -L -X POST "http://${FACTORYOWNER_IP}:8042/api/v1/owner/svi" -H 'Content-Type: text/plain' --data-raw '[{"filedesc" : "/persist/installOS.sh", "resource": "http://'"${NEXUS_IPPORT}"'/repository/raw/install_OS.sh"}]'

    fi

    printBanner "Configuration of the various services before demo ${T_OK_ICON}"
fi

if [[ "${STEP_CREATE_DI}" == "true" ]]; then
    printBanner "Creating new device VM and wait until it's off"
    cd Demo
    source "install-empty.sh" ${DEVICE_VM}
    cd ..
    #wait until VM shut down (meaning it installed, rebooted, did DI)
    vmstate=$(virsh list --all | grep " ${DEVICE_VM} " | awk '{ print $3}')
    while ([ "$vmstate" != "shut" ]); do
        sleep 5
        vmstate=$(virsh list --all | grep " ${DEVICE_VM} " | awk '{ print $3}')
        if([ "$vmstate" == "paused" ]); then
            virsh reset demo_device_vm
            virsh resume demo_device_vm
        fi
    done;
    printBanner "Creating new device VM and wait until it's off ${T_OK_ICON}"
fi

if [[ "${STEP_VOUCHER_REGISTER}" == "true" ]]; then
    printBanner "Generate a ownership voucher"
    #get info of last device that performed DI 
    DEVICE_INFO=$(curl -D - --digest -u ${MANUFACTURER_CREDS} -L -X GET "http://${MANUFACTURER_IP}:8039/api/v1/deviceinfo/100000" | grep "\[.*\]")
    SERIAL_NO=$(echo ${DEVICE_INFO} | jq -r .[length-1].serial_no)
    UUID=$(echo ${DEVICE_INFO} | jq -r .[length-1].uuid)
    #generate a certificate from factory owner
    FACTORYOWNER_CERTIFICATE=$(curl -D - --digest -u ${FACTORYOWNER_CREDS} -L -X GET "http://${FACTORYOWNER_IP}:8042/api/v1/certificate?alias=SECP256R1" -H 'Content-Type: text/plain' | grep -zo "\-\-\-\-\-.*\-\-\-\-\-")
    #use it to generate a voucher then add it to owner
    VOUCHER=$(curl -D - --digest -u ${MANUFACTURER_CREDS} -L -X POST "http://${MANUFACTURER_IP}:8039/api/v1/mfg/vouchers/${SERIAL_NO}" -H 'Content-Type: text/plain' --data-raw "$FACTORYOWNER_CERTIFICATE" | grep -zo "\-\-\-\-\-.*\-\-\-\-\-")
    curl -D - --digest -u ${FACTORYOWNER_CREDS} -L -X POST "http://${FACTORYOWNER_IP}:8042/api/v1/owner/vouchers" -H 'Content-Type: text/plain' --data-raw "$VOUCHER"

    if [[ "${STEP_VOUCHER_RESALE}" == "true" ]]; then
        printBanner "Reselling the voucher before performing TO0"
        #generate a certificate of client owner, and use it to extend the voucher, then add voucher to client owner
        CLIENTOWNER_CERTIFICATE=$(curl -D - --digest -u ${CLIENTOWNER_CREDS} -L -X GET "http://${CLIENTOWNER_IP}:8042/api/v1/certificate?alias=SECP256R1" -H 'Content-Type: text/plain' | grep -zo "\-\-\-\-\-.*\-\-\-\-\-")
        EXTENDED_VOUCHER=$(curl -D - --digest -u ${FACTORYOWNER_CREDS} -L -X POST "http://${FACTORYOWNER_IP}:8042/api/v1/resell/${UUID}" -H 'Content-Type: text/plain' --data-raw "$CLIENTOWNER_CERTIFICATE" | grep -zo "\-\-\-\-\-.*\-\-\-\-\-")
        curl -D - --digest -u ${CLIENTOWNER_CREDS} -L -X POST "http://${CLIENTOWNER_IP}:8042/api/v1/owner/vouchers" -H 'Content-Type: text/plain' --data-raw "$EXTENDED_VOUCHER"
    fi
    printBanner "Performing TO0"
    #perform TO0 with the client owner or factory owner, depending of if a resale happened
    if [[ "${STEP_VOUCHER_RESALE}" == "true" ]]; then
        curl -D - --digest -u ${CLIENTOWNER_CREDS} -L -X GET "http://${CLIENTOWNER_IP}:8042/api/v1/to0/${UUID}"
    else
        curl -D - --digest -u ${FACTORYOWNER_CREDS} -L -X GET "http://${FACTORYOWNER_IP}:8042/api/v1/to0/${UUID}"
    fi
    printBanner "Generate a ownership voucher, register it in the owner with an eventual resale and perform TO0 ${T_OK_ICON}"
fi

if [[ "${STEP_CHANGENETWORK}" == "true" ]]; then
    printBanner "Switching device over to 'client' network"
    virsh dumpxml ${DEVICE_VM} | sed "s+virbr16+virbr17+g" > ${DEVICE_VM}.xml
    virsh define ${DEVICE_VM}.xml
    printBanner "Switching device over to 'client' network ${T_OK_ICON}"
fi

if [[ "${STEP_TO1_2}" == "true" ]]; then
    printBanner "Performing TO1 and TO2"
    virsh start ${DEVICE_VM}
    vmstate=$(virsh list --all | grep " ${DEVICE_VM} " | awk '{ print $3}')
    while ([ "$vmstate" != "shut" ]); do
        sleep 5
        vmstate=$(virsh list --all | grep " ${DEVICE_VM} " | awk '{ print $3}')
    done;
    printBanner "Performing TO1 and TO2 ${T_OK_ICON}"
fi
