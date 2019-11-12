#!/bin/bash
# Before run of this script you can set environmental variables
# IMAGE_TAG, DOCKERFILE, BASE_IMG, GOLANG_OS_ARCH, .. then  export them
# and to use defined values instead of default ones

cd "$(dirname "$0")"

set -e

IMAGE_TAG=${IMAGE_TAG:-'ubuntu_cross_aarch64'}
DOCKERFILE=${DOCKERFILE:-'Dockerfile'}
BASE_IMG=${BASE_IMG:-'ubuntu:18.04'}

docker build -f ${DOCKERFILE} \
    --tag ${IMAGE_TAG} \
    --build-arg BASE_IMG=${BASE_IMG} \
    ${DOCKER_BUILD_ARGS} .
