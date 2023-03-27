#!/bin/bash

cd Run

sshpass -p password ssh demo_factory_owner_vm@192.168.127.3 < runComponent.sh
sshpass -p password ssh demo_client_owner_vm@192.168.128.2 < runComponent.sh
sshpass -p password ssh demo_manufacturer_vm@192.168.127.2 < runComponent.sh
sshpass -p password ssh demo_rendezvous_vm@192.168.128.3 < runComponent.sh
sshpass -p password ssh demo_pxe_vm@192.168.127.11 < runPXE.sh

cd ..
