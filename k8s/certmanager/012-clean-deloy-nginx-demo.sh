#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT

}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

RANCHER_VERSION="v2.3.2"
RANCHER_OS="linux-amd64"
RANCHER_PATH="../../bin/"
RANCHER_BIN="${RANCHER_PATH}rancher-${RANCHER_VERSION}-${RANCHER_OS}"
#NAMESPACE="default"

$RANCHER_BIN kubectl delete -k ../../falinux-certmanager/k8s/nginx-controller-demo
