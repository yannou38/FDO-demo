#!/bin/bash

cd Install
#create networks on host
virsh net-define network_factory.xml
virsh net-define network_client.xml
virsh net-autostart factory
virsh net-autostart client
virsh net-start factory
virsh net-start client

#run ansible
cd playbook
ansible-playbook -i hosts/hosts-machines.yml install-infra.yml
cd ..
#run specific script on each vm (sleep before to ensure domains are ready)
sleep 300

#trust the new hosts keys
ssh-keyscan 192.168.127.3 >> ~/.ssh/known_hosts
ssh-keyscan 192.168.128.2 >> ~/.ssh/known_hosts
ssh-keyscan 192.168.127.2 >> ~/.ssh/known_hosts
ssh-keyscan 192.168.128.3 >> ~/.ssh/known_hosts
ssh-keyscan 192.168.127.11 >> ~/.ssh/known_hosts

##FACTORY OWNER
sshpass -p password ssh demo_factory_owner_vm@192.168.127.3 < installOwner.sh
# ##CLIENT OWNER
sshpass -p password ssh demo_client_owner_vm@192.168.128.2 < installOwner.sh
# ##MANUFACTURER
sshpass -p password ssh demo_manufacturer_vm@192.168.127.2 < installManufacturer.sh
# ##RENDEZVOUS SERVER
sshpass -p password ssh demo_rendezvous_vm@192.168.128.3 < installRendezVous.sh
##PXE SERVER
sshpass -p password scp -r UOS_FDO demo_pxe_vm@192.168.127.11:/tmp/UOS_FDO 
sshpass -p password scp -r FDOAgentImageAlpine demo_pxe_vm@192.168.127.11:/tmp/FDOAgentImageAlpine 
sshpass -p password scp -r uosBuilder demo_pxe_vm@192.168.127.11:/tmp/uosBuilder 
sshpass -p password scp default demo_pxe_vm@192.168.127.11:/tmp/default 
sshpass -p password scp default_legacy demo_pxe_vm@192.168.127.11:/tmp/default_legacy 
sshpass -p password ssh demo_pxe_vm@192.168.127.11 < installPXE.sh
 
cd ..