#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT
cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    exit
}

DOCKER_REG="docker.falinux.dev"
DOCKER_PATH="services"
DOCKER_REG_USER="falinux"
DOCKER_REG_PASSWORD="2001May09"
DOCKER_IMG_NAME="falinux-redmine-postgresql"
DOCKER_IMG_TAG="latest"

IMAGE_BUILD_NAME="falinux-service-redmine-postgresql"

echo ""
echo "Docker image build and push registry ..."
echo ""

docker-compose build ${IMAGE_BUILD_NAME}

docker tag ${DOCKER_PATH}/${DOCKER_IMG_NAME}:${DOCKER_IMG_TAG} ${DOCKER_REG}/${DOCKER_PATH}/${DOCKER_IMG_NAME}:${DOCKER_IMG_TAG}
docker login -u ${DOCKER_REG_USER} -p ${DOCKER_REG_PASSWORD} ${DOCKER_REG}
docker push ${DOCKER_REG}/${DOCKER_PATH}/${DOCKER_IMG_NAME}:${DOCKER_IMG_TAG}
docker logout ${DOCKER_REG}
