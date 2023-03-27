FROM arm64v8/debian:stable
RUN apt update && apt install -y haveged openjdk-11-jre
RUN mkdir persist
COPY device.jar device.jar
COPY lib lib
COPY log4j2.xml log4j2.xml
COPY service.yml service.yml

ENTRYPOINT ["java","-jar","device.jar"]
