#!/usr/bin/env bash

NAME_SPACE="gitlab"

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    exit
}

echo ""
echo "${NAME_SPACE} delpoy..."
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

## user input replicase
#read -p "Enter replicas: " REPLICAS
#if [ -z "$REPLICAS" ]; then
#    echo "Replicas is empty"
#    exit 1
#fi

kubectl apply -f ../kustomize/gitlab/deployment.yaml
#kubectl apply -f ../kustomize/postgresql/deployment.yaml

kubectl --kubeconfig $KUBE_CONFIG  scale -f ../kustomize/gitlab/deployment.yaml --replicas=0
#kubectl --kubeconfig $KUBE_CONFIG  scale -f ../kustomize/postgresql/deployment.yaml --replicas=0

sleep 3;

kubectl --kubeconfig $KUBE_CONFIG  scale -f ../kustomize/gitlab/deployment.yaml --replicas=1
#kubectl --kubeconfig $KUBE_CONFIG  scale -f ../kustomize/postgresql/deployment.yaml --replicas=1


