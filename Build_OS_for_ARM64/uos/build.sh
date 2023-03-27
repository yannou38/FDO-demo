#! /bin/bash

docker build -f Dockerfile.alpine -t alpine/kernel:v3.0 .
docker build -f Dockerfile.dyninit -t user/dyninit:v1.0 .
linuxkit build -docker -format kernel+initrd uos.yml


