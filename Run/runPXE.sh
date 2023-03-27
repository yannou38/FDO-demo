#!/bin/bash

name=$(whoami)
echo "password" | sudo -S -v
sudo -i -u root bash << EOF
cd /home/${name}/Edge-Software-Provisioner/ && ./run.sh -f -n 
EOF