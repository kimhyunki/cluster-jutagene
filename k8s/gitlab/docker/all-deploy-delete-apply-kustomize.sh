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

kubectl --kubeconfig $KUBE_CONFIG delete -k ../kustomize/gitlab
kubectl --kubeconfig $KUBE_CONFIG delete -k ../kustomize/postgresql
kubectl --kubeconfig $KUBE_CONFIG delete -k ../kustomize/redis

#kubectl --kubeconfig $KUBE_CONFIG delete -f ../kustomize/gitlab/pvc.yaml
#kubectl --kubeconfig $KUBE_CONFIG delete -f ../kustomize/postgresql/pvc.yaml
#kubectl --kubeconfig $KUBE_CONFIG delete -f ../kustomize/redis/pvc.yaml

sleep 3

#kubectl --kubeconfig $KUBE_CONFIG apply -f ../kustomize/gitlab/pvc.yaml
#kubectl --kubeconfig $KUBE_CONFIG apply -f ../kustomize/postgresql/pvc.yaml
#kubectl --kubeconfig $KUBE_CONFIG apply -f ../kustomize/redis/pvc.yaml

kubectl --kubeconfig $KUBE_CONFIG apply -k ../kustomize/gitlab
kubectl --kubeconfig $KUBE_CONFIG apply -k ../kustomize/postgresql
kubectl --kubeconfig $KUBE_CONFIG apply -k ../kustomize/redis
