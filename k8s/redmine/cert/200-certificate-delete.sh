#!/usr/bin/env bash
 
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    exit
}

FILE_DESCRIPTOR="Remind issuer apply"
CERT_NAME="rm-falinux-dev"
DNS_NAME="rm.falinux.dev"

echo "File descriptor: $FILE_DESCRIPTOR"
echo "Certificate name: $CERT_NAME"
echo "DNS name: $DNS_NAME"

echo ""
echo "$FILE_DESCRIPTOR"
echo ""
echo " 1) main cluster"
echo " 2) clone cluster"
echo " 3) b cluster"
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
        echo "b cluster selected"
        KUBE_CONFIG="$HOME/.kube/config-b"
        ;;
esac


echo "
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: ${CERT_NAME}
  namespace: redmine
spec:
  secretName: ${CERT_NAME}-tls
  issuerRef:
    name: letsencrypt-prod
  commonName: ${DNS_NAME}
  dnsNames:
  - ${DNS_NAME}
" | kubectl --kubeconfig $KUBE_CONFIG delete -f -
