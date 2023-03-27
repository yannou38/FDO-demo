#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

PROVISION_LOG="/tmp/provisioning.log"
run "Begin provisioning process..." \
    "while (! docker ps > /dev/null ); do sleep 0.5; done" \
    ${PROVISION_LOG}

PROVISIONER=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"proxy="* ]]; then
	tmp="${kernel_params##*proxy=}"
	export param_proxy="${tmp%% *}"

	export http_proxy=${param_proxy}
	export https_proxy=${param_proxy}
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=${param_proxy}
	export HTTPS_PROXY=${param_proxy}
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
elif [ $( nc -vz ${PROVISIONER} 3128; echo $?; ) -eq 0 ] && [ $( nc -vz ${PROVISIONER} 4128; echo $?; ) -eq 0 ]; then
	PROXY_DOCKER_BIND="-v /tmp/ssl:/etc/ssl/ -v /usr/local/share/ca-certificates/EB.pem:/usr/local/share/ca-certificates/EB.crt"
    export http_proxy=http://${PROVISIONER}:3128/
	export https_proxy=http://${PROVISIONER}:4128/
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=http://${PROVISIONER}:3128/
	export HTTPS_PROXY=http://${PROVISIONER}:4128/
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}' ${PROXY_DOCKER_BIND}"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}'; if [ ! -f /usr/local/share/ca-certificates/EB.crt ]; then if (! which wget > /dev/null ); then apt update && apt -y install wget; fi; wget -O - http://${PROVISIONER}/squid-cert/CA.pem > /usr/local/share/ca-certificates/EB.crt && update-ca-certificates; fi;"
    wget -O - http://${PROVISIONER}/squid-cert/CA.pem > /usr/local/share/ca-certificates/EB.pem
    update-ca-certificates
elif [ $( nc -vz ${PROVISIONER} 3128; echo $?; ) -eq 0 ]; then
	export http_proxy=http://${PROVISIONER}:3128/
	export https_proxy=http://${PROVISIONER}:3128/
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=http://${PROVISIONER}:3128/
	export HTTPS_PROXY=http://${PROVISIONER}:3128/
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
fi

if [[ $kernel_params == *"proxysocks="* ]]; then
	tmp="${kernel_params##*proxysocks=}"
	param_proxysocks="${tmp%% *}"

	export FTP_PROXY=${param_proxysocks}

	tmp_socks=$(echo ${param_proxysocks} | sed "s#http://##g" | sed "s#https://##g" | sed "s#/##g")
	export SSH_PROXY_CMD="-o ProxyCommand='nc -x ${tmp_socks} %h %p'"
fi

if [[ $kernel_params == *"httppath="* ]]; then
	tmp="${kernel_params##*httppath=}"
	export param_httppath="${tmp%% *}"
fi

if [[ $kernel_params == *"parttype="* ]]; then
	tmp="${kernel_params##*parttype=}"
	export param_parttype="${tmp%% *}"
elif [ -d /sys/firmware/efi ]; then
	export param_parttype="efi"
else
	export param_parttype="msdos"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
	tmp="${kernel_params##*bootstrap=}"
	export param_bootstrap="${tmp%% *}"
	export param_bootstrapurl=$(echo $param_bootstrap | sed "s#/$(basename $param_bootstrap)\$##g")
fi

if [[ $kernel_params == *"kernparam="* ]]; then
	tmp="${kernel_params##*kernparam=}"
	temp_param_kernparam="${tmp%% *}"
	export param_kernparam=$(echo ${temp_param_kernparam} | sed 's/#/ /g' | sed 's/:/=/g')
fi

if [[ $kernel_params == *"kernelversion="* ]]; then
	tmp="${kernel_params##*kernelversion=}"
	export param_kernelversion="${tmp%% *}"
else
	export param_kernelversion="linux-image-generic"
fi

if [[ $kernel_params == *"release="* ]]; then
	tmp="${kernel_params##*release=}"
	export param_release="${tmp%% *}"
else
	export param_release='dev'
fi

if [[ $param_release == 'prod' ]]; then
	export kernel_params="$param_kernparam" # ipv6.disable=1
else
	export kernel_params="$param_kernparam"
fi


# --- Get free memory
export freemem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# --- Detect HDD ---
if [ -d /sys/block/nvme[0-9]n[0-9] ]; then
	export DRIVE=$(echo /dev/$(ls -l /sys/block/nvme* | grep -v usb | head -n1 | sed 's/^.*\(nvme[a-z0-1]\+\).*$/\1/'))
	if [[ $param_parttype == 'efi' ]]; then
		export EFI_PARTITION=${DRIVE}p1
		export BOOT_PARTITION=${DRIVE}p2
		export SWAP_PARTITION=${DRIVE}p3
		export ROOT_PARTITION=${DRIVE}p4
	else
		export BOOT_PARTITION=${DRIVE}p1
		export SWAP_PARTITION=${DRIVE}p2
		export ROOT_PARTITION=${DRIVE}p3
	fi
elif [ -d /sys/block/[vsh]da ]; then
	export DRIVE=$(echo /dev/$(ls -l /sys/block/[vsh]da | grep -v usb | head -n1 | sed 's/^.*\([vsh]d[a-z]\+\).*$/\1/'))
	if [[ $param_parttype == 'efi' ]]; then
		export EFI_PARTITION=${DRIVE}1
		export BOOT_PARTITION=${DRIVE}2
		export SWAP_PARTITION=${DRIVE}3
		export ROOT_PARTITION=${DRIVE}4
	else
		export BOOT_PARTITION=${DRIVE}1
		export SWAP_PARTITION=${DRIVE}2
		export ROOT_PARTITION=${DRIVE}3
	fi
elif [ -d /sys/block/mmcblk[0-9] ]; then
	export DRIVE=$(echo /dev/$(ls -l /sys/block/mmcblk[0-9] | grep -v usb | head -n1 | sed 's/^.*\(mmcblk[0-9]\+\).*$/\1/'))
	if [[ $param_parttype == 'efi' ]]; then
		export EFI_PARTITION=${DRIVE}p1
		export BOOT_PARTITION=${DRIVE}p2
		export SWAP_PARTITION=${DRIVE}p3
		export ROOT_PARTITION=${DRIVE}p4
	else
		export BOOT_PARTITION=${DRIVE}p1
		export SWAP_PARTITION=${DRIVE}p2
		export ROOT_PARTITION=${DRIVE}p3
	fi
else
	echo "No supported drives found!" 2>&1 | tee -a /dev/console
	sleep 300
	reboot
fi

export BOOTFS=/target/boot
export ROOTFS=/target/root
mkdir -p $BOOTFS
mkdir -p $ROOTFS

echo "" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console
echo "Installing on ${DRIVE}" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console

# --- Partition HDD ---
run "Partitioning drive ${DRIVE}" \
    "if [[ $param_parttype == 'efi' ]]; then
        parted --script ${DRIVE} \
        mklabel gpt \
        mkpart ESP fat32 1MiB 1024MiB \
        set 1 esp on \
        mkpart primary ext4 1024MiB 2048MiB \
        mkpart primary linux-swap 2048MiB 3072MiB \
        mkpart primary 3072MiB 100%;
    else
        parted --script ${DRIVE} \
        mklabel msdos \
        mkpart primary ext4 1MiB 1024MiB \
        set 1 boot on \
        mkpart primary linux-swap 1024MiB 2048MiB \
        mkpart primary 2048MiB 100%;
    fi" \
    ${PROVISION_LOG}

# --- Create file systems ---
run "Creating boot partition on drive ${DRIVE}" \
    "mkfs -t ext4 -L BOOT -F ${BOOT_PARTITION} && \
    e2label ${BOOT_PARTITION} BOOT && \
    mkdir -p $BOOTFS && \
    mount ${BOOT_PARTITION} $BOOTFS" \
    ${PROVISION_LOG}

if [[ $param_parttype == 'efi' ]]; then
    export EFIFS=$BOOTFS/efi
    mkdir -p $EFIFS
    run "Creating efi boot partition on drive ${DRIVE}" \
        "mkfs -t vfat -n BOOT ${EFI_PARTITION} && \
        mkdir -p $EFIFS && \
        mount ${EFI_PARTITION} $EFIFS" \
        ${PROVISION_LOG}
fi

# --- Create ROOT file system ---
run "Creating root file system" \
    "mkfs -t ext4 ${ROOT_PARTITION} && \
    mount ${ROOT_PARTITION} $ROOTFS && \
    e2label ${ROOT_PARTITION} STATE_PARTITION" \
    ${PROVISION_LOG}

run "Creating swap file system" \
    "mkswap ${SWAP_PARTITION}" \
    ${PROVISION_LOG}

# --- check if we need to add memory ---
if [ $freemem -lt 6291456 ]; then
    fallocate -l 2G $ROOTFS/swap
    chmod 600 $ROOTFS/swap
    mkswap $ROOTFS/swap
    swapon $ROOTFS/swap
fi

# --- check if we need to move tmp folder ---
if [ $freemem -lt 6291456 ]; then
    mkdir -p $ROOTFS/tmp
    export TMP=$ROOTFS/tmp
else
    export TMP=/tmp
fi
export PROVISION_LOG="$TMP/provisioning.log"

if [ $(wget http://${PROVISIONER}:5557/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5557"
elif [ $(wget http://${PROVISIONER}:5000/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5000"
fi


# -- Configure Image database ---
run "Configuring Image Database" \
    "mkdir -p $ROOTFS/tmp/docker && \
    chmod 777 $ROOTFS/tmp && \
    killall dockerd && sleep 2 && \
    /usr/local/bin/dockerd ${REGISTRY_MIRROR} --data-root=$ROOTFS/tmp/docker > /dev/null 2>&1 &" \
    "$TMP/provisioning.log"


sleep 5

#while ( docker ps > /dev/null ); do sleep 0.5; done
while (! docker ps > /dev/null ); do sleep 0.5; done


run "Begin Device Initialization..." \
    "sleep 0.5" \
    "$TMP/provisioning.log"


#create a 10 Character MString
MSTRING="$(tr </dev/urandom -dc a-f0-9 | head -c16)"
echo "MSTRING=$MSTRING" | tee $BOOTFS/SerialNo.txt

if [[ $param_parttype == 'efi' ]]; then
run "Making ${DRIVE} bootable for FDO-TO on EFI" \
    "mkdir  -p $EFIFS/EFI && cd $EFIFS/EFI && \
    wget --no-check-certificate -O BOOT.tgz ${param_bootstrapurl}/files/BOOT.tgz && \
    tar xvf BOOT.tgz && \
    cd $EFIFS/EFI/BOOT && \
    sed -i s/@@PROVISIONER@@/${PROVISIONER}/g grub.cfg && \
    sed -i "s~@@PROXY@@~${param_proxy}~g" grub.cfg && \
    wget --no-check-certificate -O vmlinuz http://${PROVISIONER}/tftp/images/uos/vmlinuz && \
    wget --no-check-certificate -O initrd http://${PROVISIONER}/tftp/images/uos/initrd  "  \
    "$TMP/provisioning.log"
else
run "Begin Make ${DRIVE} BIOS bootable..." \
    "mkdir -p $BOOTFS && cd $BOOTFS && \
    dd bs=440 count=1 conv=notrunc if=/usr/share/syslinux/mbr.bin of=${DRIVE} && \
    wget --no-check-certificate -O extlinux.conf ${param_bootstrapurl}/files/extlinux.conf && \
    cd $BOOTFS &&  sed -i s/@@PROVISIONER@@/${PROVISIONER}/g extlinux.conf && \
    wget --no-check-certificate -O vmlinuz http://${PROVISIONER}/tftp/images/uos/vmlinuz && sync && \
    wget --no-check-certificate -O initrd http://${PROVISIONER}/tftp/images/uos/initrd &&  sync && \
    extlinux --install ${BOOTFS} && sleep 5 "\
    "$TMP/provisioning.log"
fi

if [[ $param_parttype == 'efi' ]]; then
    efibootmgr 2>&1 | tee -a /dev/console
    echo "" 2>&1 | tee -a /dev/console
    echo "" 2>&1 | tee -a /dev/console

    run "Removing old Ubuntu boot entries " "" "$TMP/provisioning.log"
    for i in `efibootmgr | grep -i ubuntu | awk '{print substr ($0,8,1)}' | sed ':a;N;$!ba;s/\n/ /g' `
     do
     efibootmgr -b ${i} -B 2>&1
    done

    run "Removing old Yocto boot entries " "" "$TMP/provisioning.log"
    for i in `efibootmgr | grep -i yocto | awk '{print substr ($0,8,1)}' | sed ':a;N;$!ba;s/\n/ /g' `
     do
     efibootmgr -b ${i} -B 2>&1
    done

   run "Setting Next Boot from Hard disk " "" "$TMP/provisioning.log"
   if [[ `efibootmgr | grep -i "uefi vbox harddisk | wc -l` ==  '1' ]]; then
   efibootmgr -n  `efibootmgr | grep -i "uefi vbox harddisk" |  awk '{print substr ($0,8,1)}' ` 2&>1
   efibootmgr -o  `efibootmgr | grep -i "uefi vbox harddisk" |  awk '{print substr ($0,8,1)}' ` 2&>1
   fi
   if [[ `efibootmgr | grep -i "uefi os" | wc -l` ==  '1' ]]; then
   efibootmgr -n  `efibootmgr | grep -i "uefi os" |  awk '{print substr ($0,8,1)}' ` 2&>1
   efibootmgr -o  `efibootmgr | grep -i "uefi os" |  awk '{print substr ($0,8,1)}' ` 2&>1
   fi
   efibootmgr 2>&1 | tee -a /dev/console
else
   run "Warning!! This is a Legacy BIOS system without EFI, You may to select the next Boot from Hard disk from BIOS or the PXE menu " "sleep 1" "$TMP/provisioning.log"
fi

run "Loading FDO device image... " \
    "cd $ROOTFS && wget --no-check-certificate -O fdodevice.tar.gz ${param_bootstrapurl}/files/fdodevice.tar.gz" \
    "$TMP/provisioning.log"


run "FDO Device deployment completed... rebooting " \
    "sleep 1 &&  \
     reboot " \
    "$TMP/provisioning.log"


