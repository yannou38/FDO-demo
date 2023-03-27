#!/bin/bash

echo "password" | sudo -S apt update
echo "password" | sudo -S apt install -y maven haveged openjdk-11-jdk docker docker-compose
git clone https://github.com/secure-device-onboard/pri-fidoiot.git --branch v1.1.0.2 --depth 1
cd pri-fidoiot
mvn clean install
cd ..

ln -s ~/pri-fidoiot/component-samples/demo/owner ~/component
cd component
#delete the line containing the TO0Scheduler
sed -i '/To0Scheduler/d' service.yml
