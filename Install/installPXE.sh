#!/bin/bash

name=$(whoami)
echo "password" | sudo -S apt update
echo "password" | sudo -S apt install -y docker docker-compose

git clone https://github.com/intel/Edge-Software-Provisioner.git --branch v2.5.0 --depth 1
cd Edge-Software-Provisioner
#command to get sudo credentials in cache before running the build after... could not find a better way
echo "password" | sudo -S -v
sudo -i -u root bash << EOF
cd /home/${name}/Edge-Software-Provisioner/ && ./build.sh -s
EOF

echo "password" | sudo -S cp /tmp/default_legacy ~/Edge-Software-Provisioner/data/srv/tftp/pxelinux.cfg_legacy/default
echo "password" | sudo -S cp /tmp/default ~/Edge-Software-Provisioner/data/srv/tftp/pxelinux.cfg/default
echo "password" | sudo -S cp -r /tmp/UOS_FDO/ ~/Edge-Software-Provisioner/data/usr/share/nginx/html/profile/


echo "password" | sudo -S cp -r /tmp/uosBuilder/ ~/uosBuilder
echo "password" | sudo -S cp -r /tmp/FDOAgentImageAlpine/ ~/FDOAgentImageAlpine

chmod 775 ~/Edge-Software-Provisioner/data/srv/tftp/pxelinux.cfg_legacy/default ~/Edge-Software-Provisioner/data/srv/tftp/pxelinux.cfg/default 
chmod 775 -R ~/Edge-Software-Provisioner/data/usr/share/nginx/html/profile/ ~/uosBuilder ~/FDOAgentImageAlpine

chown -R demo_pxe_vm ~/Edge-Software-Provisioner/data/srv/tftp/pxelinux.cfg_legacy/default ~/Edge-Software-Provisioner/data/srv/tftp/pxelinux.cfg/default 
chown -R demo_pxe_vm -R ~/Edge-Software-Provisioner/data/usr/share/nginx/html/profile/ ~/uosBuilder ~/FDOAgentImageAlpine


#command to get sudo credentials in cache before running the build after... could not find a better way
echo "password" | sudo -S -v
sudo -i -u root bash << EOF
cd /home/${name}/uosBuilder/ && chmod +x build.sh && chmod +x dockerfiles/uos/prepInitrd.sh && ./build.sh
EOF

#command to get sudo credentials in cache before running the build after... could not find a better way
echo "password" | sudo -S -v
sudo -i -u root bash << EOF
cd /home/${name}/FDOAgentImageAlpine/ && chmod +x build.sh && ./build.sh
EOF
