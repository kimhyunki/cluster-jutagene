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


# default settings 
setup_colors

################################################################################

if [ ! -f /usr/local/bin/helm ]; then
  # install qestion yes/no
  read -p "Do you want to install helm? (y/n) " -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing helm..."
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
  else
    echo "Helm is not installed. Please install helm first."
    exit 1
  fi
fi

# helm init --client-only

helm repo add bitnami https://charts.bitnami.com/bitnami

# helm uninstall my-release
#  helm search repo bitnami/wordpress --versions
# helm install my-release bitnami/wordpress --version 14.3.2
helm install my-release bitnami/wordpress --version 15.1.0

# helm install my-release \
#   bitnami/wordpress

  # --set ingress.enabled=true \
  # --set ingress.hostname=www.juxtagene.com \
  # --set ingress.certManager=true \
  # --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  # --set ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
  # --set ingress.tls[0].secretName=www-juxtagene-com-tls \
  # --set ingress.tls[0].hosts[0]=www.juxtagene.com \

exit


helm install --kubeconfig ~/.kube/config \
	$RELEASE_NAME apache-airflow/airflow \
  --namespace $NAMESPACE \
  --set-string "env[0].name=AIRFLOW__CORE__LOAD_EXAMPLES" \
  --set-string "env[0].value=True" \
  --set-string redis.persistence.storageClassName=gluster-heketi \
  --set-string logs.persistence.storageClassName=gluster-heketi \
  --set-string dags.persistence.storageClassName=gluster-heketi \
  --set-string workers.persistence.storageClassName=gluster-heketi \
  --set-string workers.persistence.size=10G \
  --set-string triggerer.persistence.storageClassName=gluster-heketi \
  --set-string triggerer.persistence.size=10G \
  -f ./values.yaml

echo "1)"
echo "2) "
echo "Choose an number:" | tr -d '\n'
read CHOOSE_CMD 
case $CHOOSE_CMD in
  1)
  ;;
  2)
  ;;
  *) 
    echo "You did not choose!"
    ;;
esac