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

RANCHER_PATH="../bin/"
RANCHER_BIN="${RANCHER_PATH}rancher"
NAMESPACE="cert-manager"

if $RANCHER_BIN namespace $NAMESPACE &> /dev/null
then
    msg "${BLUE}===> Namespace $NAMESPACE already exists...${NOFORMAT}"
else
    msg "${BLUE}===> Creating namespace $NAMESPACE...${NOFORMAT}"
    $RANCHER_BIN namespace create $NAMESPACE
fi

$RANCHER_BIN context switch

# Install cert-manager
$RANCHER_BIN kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml

