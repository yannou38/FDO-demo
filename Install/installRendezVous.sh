#!/bin/bash

echo "password" | sudo -S apt update
echo "password" | sudo -S apt install -y maven haveged openjdk-11-jdk docker docker-compose
git clone https://github.com/secure-device-onboard/pri-fidoiot.git --branch v1.1.0.2 --depth 1
ln -s ~/pri-fidoiot/component-samples/demo/rv ~/component

cd component
sed -i 's/127.0.0.1/192.168.128.3/g' service.yml
cd ..

cd pri-fidoiot
mvn clean install
