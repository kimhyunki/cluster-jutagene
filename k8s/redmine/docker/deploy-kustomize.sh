#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    git checkout -- docker-compose.yml
    exit
}

echo ""
echo "redmine delpoy..."
echo ""
echo " 1) main cluster"
echo " 2) clone cluster"
echo " 3) erp2 cluster"
echo ""
echo -n "Select: "
read KUBE_CONFIG_SELECTION

case $KUBE_CONFIG_SELECTION in
1)
    echo "main cluster selected"
    KUBE_CONFIG="$HOME/.kube/config-main"
    ;;
2)
    echo "clone cluster selected"
    KUBE_CONFIG="$HOME/.kube/config-clone"
    ;;
3)
    echo "erp2 cluster selected"
    KUBE_CONFIG="$HOME/.kube/config-erp2"
    ;;
esac

SERVICE_VERSION="0.1"
# current version print
echo ""
echo "current version: ${SERVICE_VERSION}"
echo ""

# if current version change
echo -n "if current version change, input new version: "
read SERVICE_VERSION
if [ -z "$SERVICE_VERSION" ]; then
    echo "version not changed"
    SERVICE_VERSION="0.1"
else
    echo "version changed to ${SERVICE_VERSION}"
fi

sed -i "s/:{{SERVICE_VERSION}}/:${SERVICE_VERSION}/g" docker-compose.yml

docker-compose build

docker tag services/falinux-redmine:${SERVICE_VERSION} docker.nemopai.com/services/falinux-redmine:${SERVICE_VERSION}
docker tag services/falinux-redmine-postgresql:${SERVICE_VERSION} docker.nemopai.com/services/falinux-redmine-postgresql:${SERVICE_VERSION}

docker login -u falinux -p "2001May09" docker.nemopai.com
docker push docker.nemopai.com/services/falinux-redmine:${SERVICE_VERSION}
docker push docker.nemopai.com/services/falinux-redmine-postgresql:${SERVICE_VERSION}
docker logout docker.nemopai.com
