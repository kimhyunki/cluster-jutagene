#!/usr/bin/env bash

set -Eeuo pipefail

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' \
    ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' \
    CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

#-------------------------------------------------------------------------------
# default settings 
setup_colors

KUBE_DEFALUT_CONFIG="$HOME/.kube/config"
KUBE_COSTOM_CONFIG="$HOME/.kube/config-olaf"

cp $KUBE_COSTOM_CONFIG $KUBE_DEFALUT_CONFIG

kubectl --kubeconfig "$KUBE_DEFALUT_CONFIG" patch storageclass rook-ceph-block \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl --kubeconfig "$KUBE_DEFALUT_CONFIG" patch storageclass rook-cephfs \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl get storageclass
