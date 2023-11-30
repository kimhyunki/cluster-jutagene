#!/usr/bin/env bash

NAME_SPACE="redmine"

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    exit
}

echo ""
echo "redmine delpoy..."
echo ""
echo " 1) main cluster"
echo " 2) clone cluster"
echo " 3) erp2 cluster"
echo " 4) b cluster"
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
4)
    echo "b cluster selected"
    KUBE_CONFIG="$HOME/.kube/config-b"
    ;;
esac

IF_NS=$(kubectl --kubeconfig "$KUBE_CONFIG" get ns | grep "$NAME_SPACE")

if [ -z "$IF_NS" ]; then
    kubectl --kubeconfig "$KUBE_CONFIG" create namespace "$NAME_SPACE"
fi

kubectl --kubeconfig $KUBE_CONFIG apply -k ../kustomize-postgresql/
kubectl --kubeconfig $KUBE_CONFIG apply -k ../kustomize-redmine
