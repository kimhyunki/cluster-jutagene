#!/usr/bin/env bash

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
esac

kubectl --kubeconfig "${KUBE_CONFIG}" label node r0-s04 storagenode-