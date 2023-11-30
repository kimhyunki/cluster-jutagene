#!/usr/bin/env bash
 
FILE_DESCRIPTOR="Remind pvc apply"

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

kubectl --kubeconfig $KUBE_CONFIG apply -f ../kustomize-postgresql/pvc.yaml
kubectl --kubeconfig $KUBE_CONFIG apply -f ../kustomize-redmine/pvc.yaml

