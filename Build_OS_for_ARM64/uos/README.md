# Introduction 

To build the uos (kernel+initrd) loaded by the PXE server on the bare-metal Device at first boot, we use this repo: we start from this repo : https://github.com/intel/retail-node-installer. 
We did not use the latest repo (https://github.com/intel/Edge-Software-Provisioner) because the uos seems to be based on Intel artifacts which might not work for ARM.

# Adapting kernel + dyninit build

We adapt the Dockerfile to build the kernel+initrd for ARM64 since the default one is for x86_64 Architecture. 


# Build uos for ARM64

## Install linuxkit

You can download and build linuxkit from the repo: https://github.com/linuxkit/linuxkit

## Build format: kernel+initrd

    linuxkit build -docker -format kernel+initrd uos.yml
