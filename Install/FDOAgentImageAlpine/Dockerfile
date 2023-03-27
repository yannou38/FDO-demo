FROM alpine:3.12
RUN apk update && apk add haveged openjdk11
RUN mkdir persist
COPY device.jar device.jar
COPY lib lib
COPY log4j2.xml log4j2.xml
COPY service.yml service.yml

ENTRYPOINT ["java","-jar","device.jar"]
