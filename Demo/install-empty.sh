#!/bin/bash
path=$(pwd)
# Take one argument from the commandline: VM name

if ! [ $# -eq 1 ]; then
    echo "Usage: $0 <node-name>"
    exit 1
fi

# Check if domain already exists
virsh dominfo $1 > /dev/null 2>&1
if [ "$?" -eq 0 ]; then
    echo -n "[WARNING] $1 already exists.  "
    read -p "Do you want to overwrite $1 [y/N]? " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
    else
        echo -e "\nNot overwriting $1. Exiting..."
        exit 1
    fi
fi


# Directory to store images
DIR=$(pwd)
IMAGEDF=img.qcow2
# Location of cloud image
IMAGE=$DIR/$IMAGEDF

# Cloud init files
DISK=$1.qcow2

# Bridge for VMs (default on Fedora is virbr0)
BRIDGE=virbr0

# Start clean
rm -rf $DIR/$1
mkdir -p $DIR/$1

pushd $DIR/$1 > /dev/null

    # Create log file
    touch $1.log

    echo "$(date -R) Destroying the $1 domain (if it exists)..."

    # Remove domain with the same name
    virsh destroy  $1 >> $1.log 2>&1
    virsh undefine --remove-all-storage $1 >> $1.log 2>&1


    echo "$(date -R) Copying template image..."
    cp $IMAGE $DISK

    echo "$(date -R) Installing the domain and adjusting the configuration..."
    echo "[INFO] Installing with the following parameters:"

    virt-install --accelerate --hvm --connect qemu:///system \
    --network bridge=virbr16 --pxe\
    --name $1 --ram=4096 \
    --vcpus=1 \
    --os-type=linux --os-variant=generic \
    --file=$path/$1/$1.qcow2 --noautoconsole
    sleep 3
    virsh destroy $1
    virsh dumpxml $1 > presed.xml
    virsh dumpxml $1 | sed "s+<boot dev='hd'/>+<boot dev='hd'/>\n    <boot dev='network'/>+g" > $1.xml
    virsh define $1.xml
    virsh start $1
    echo "$(date -R) DONE. Name $1"

popd > /dev/null

