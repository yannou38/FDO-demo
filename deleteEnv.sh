#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root on the target server\e[0m"
    exit 1
fi

virsh destroy demo_factory_owner_vm
virsh destroy demo_client_owner_vm
virsh destroy demo_manufacturer_vm
virsh destroy demo_rendezvous_vm
virsh destroy demo_pxe_vm
virsh destroy demo_device_vm
virsh undefine demo_factory_owner_vm --remove-all-storage
virsh undefine demo_client_owner_vm --remove-all-storage
virsh undefine demo_manufacturer_vm --remove-all-storage
virsh undefine demo_rendezvous_vm --remove-all-storage
virsh undefine demo_pxe_vm --remove-all-storage
virsh undefine demo_device_vm --remove-all-storage
rm -f /var/lib/libvirt/images/demo_factory_owner_vm.img
rm -f /var/lib/libvirt/images/demo_client_owner_vm.img
rm -f /var/lib/libvirt/images/demo_manufacturer_vm.img
rm -f /var/lib/libvirt/images/demo_rendezvous_vm.img
rm -f /var/lib/libvirt/images/demo_pxe_vm.img
rm -rf ./demo_device_vm


virsh net-destroy factory
virsh net-destroy client
virsh net-undefine factory
virsh net-undefine client