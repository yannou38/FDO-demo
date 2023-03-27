# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='localhost,127.0.0.1'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='localhost,127.0.0.1'"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
fi
docker build $1 $DOCKER_BUILD_ARGS -t fdodevice:alpine .
docker save fdodevice:alpine | gzip > /home/demo_pxe_vm/Edge-Software-Provisioner/data/usr/share/nginx/html/profile/UOS_FDO/files/fdodevice.tar.gz
chmod 664 /home/demo_pxe_vm/Edge-Software-Provisioner/data/usr/share/nginx/html/profile/UOS_FDO/files/fdodevice.tar.gz
chown demo_pxe_vm /home/demo_pxe_vm/Edge-Software-Provisioner/data/usr/share/nginx/html/profile/UOS_FDO/files/fdodevice.tar.gz
