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

# --------------------------------------------------------------------------------
# default settings
setup_colors

RANCHER_TOKEN=""
_RANCHER_TOKEN="${2:-$RANCHER_TOKEN}"

RANCHER_URL="https://rancher.falinux.dev/v3"
_RANCHER_URL="${1:-$RANCHER_URL}"

RANCHER_PATH="./bin/"
RANCHER_BIN="${RANCHER_PATH}rancher"

# arrays
# hostname, ipmi mac, ipmi ip, eth ip, ib ip, ipmi user, ipmi pass
declare -a pandora_machines_info=(
  "vm00" "xxxx" "xxxx" "10.10.100.90" "xxxx" "root" "xxxxx"
  "vm01" "xxxx" "xxxx" "10.10.100.91" "xxxx" "root" "xxxxx"
  "vm02" "xxxx" "xxxx" "10.10.100.92" "xxxx" "root" "xxxxx"
)

declare -a array_pandora_machine_name=()
declare -a array_pandora_machine_ipmi_mac=()
declare -a array_pandora_machine_ipmi_ip=()
declare -a array_pandora_machine_eth_ip=()
declare -a array_pandora_machine_ib_ip=()
declare -a array_pandora_machine_ipmi_user=()
declare -a array_pandora_machine_ipmi_pass=()
# --------------------------------------------------------------------------------
################################################################################
#-------------------------------------------------------------------------------
# define functions
function pandora_machines_info_split() {
  MOD=7
  msg "${GREEN}#-pandora_machines_info_split${NOFORMAT}"
  for ((i = 0; i < ${#pandora_machines_info[@]}; i++)); do
    if [ $((i % $MOD)) -eq 0 ]; then
      array_pandora_machine_name+=("${pandora_machines_info[$i]}")
    elif [ $((i % $MOD)) -eq 1 ]; then
      array_pandora_machine_ipmi_mac+=("${pandora_machines_info[$i]}")
    elif [ $((i % $MOD)) -eq 2 ]; then
      array_pandora_machine_ipmi_ip+=("${pandora_machines_info[$i]}")
    elif [ $((i % $MOD)) -eq 3 ]; then
      array_pandora_machine_eth_ip+=("${pandora_machines_info[$i]}")
    elif [ $((i % $MOD)) -eq 4 ]; then
      array_pandora_machine_ib_ip+=("${pandora_machines_info[$i]}")
    elif [ $((i % $MOD)) -eq 5 ]; then
      array_pandora_machine_ipmi_user+=("${pandora_machines_info[$i]}")
    elif [ $((i % $MOD)) -eq 6 ]; then
      array_pandora_machine_ipmi_pass+=("${pandora_machines_info[$i]}")
    else
      echo "error"
      exit
    fi
  done
  for ((i = 0; i < ${#array_pandora_machine_name[@]}; i++)); do
    msg "\t${array_pandora_machine_name[$i]} ${array_pandora_machine_ipmi_mac[$i]}\
    ${array_pandora_machine_ipmi_ip[$i]} ${array_pandora_machine_eth_ip[$i]}\
    ${array_pandora_machine_ib_ip[$i]}"
  done
}

array_maas_sysid=()
MAAS_USER="falinux"

function maas_prepare_machines() {
  msg "${GREEN}#-maas_prepare_machines${NOFORMAT}"

  # 마스에 등록된 머신을 찾는다.
  for ((i = 0; i < ${#array_pandora_machine_name[@]}; i++)); do
    # 등록 되어 있는지 호스트 이름으로 확인.
    MACHINE_NAME=$(sudo maas ${MAAS_USER} machines read | jq -r --arg hostname ${array_pandora_machine_name[$i]} '.[] | select(.hostname == $hostname) | .hostname')
    if [ ! -z "${MACHINE_NAME}" ]; then
      # delete machine
      msg "\tdelete machine ${array_pandora_machine_name[$i]}"
      SYSTEM_ID=$(sudo maas ${MAAS_USER} machines read | jq -r '.[] | select(.hostname == "'${array_pandora_machine_name[$i]}'") | .system_id')
      sudo maas ${MAAS_USER} machine delete ${SYSTEM_ID} >/dev/null
      sudo ipmitool -I lanplus -H ${array_pandora_machine_ipmi_ip[$i]} -U ${array_pandora_machine_ipmi_user[$i]} -P ${array_pandora_machine_ipmi_pass[$i]} chassis power off
    fi
  done

  for ((i = 0; i < ${#array_pandora_machine_name[@]}; i++)); do
    # 등록 되어 있는지 호스트 이름으로 확인.
    MACHINE_NAME=$(sudo maas ${MAAS_USER} machines read | jq -r --arg hostname ${array_pandora_machine_name[$i]} '.[] | select(.hostname == $hostname) | .hostname')
    if [ -z "${MACHINE_NAME}" ]; then
      # add machine
      sudo maas ${MAAS_USER} machines create \
        hostname=${array_pandora_machine_name[$i]} \
        fqdn=${array_pandora_machine_name[$i]}.maas \
        mac_addresses=${array_pandora_machine_ipmi_mac[$i]} \
        architecture=amd64 \
        power_type=ipmi \
        power_parameters_power_driver=LAN_2_0 \
        power_parameters_power_user=${array_pandora_machine_ipmi_user[$i]} \
        power_parameters_power_pass=${array_pandora_machine_ipmi_pass[$i]} \
        power_parameters_power_address=${array_pandora_machine_ipmi_ip[$i]} >/dev/null
    fi
  done

}

function maas_deploy_machines() {
  msg "${GREEN}#-maas_deploy_machines${NOFORMAT}"

  array_machine_ready=()

  for ((i = 0; i < ${#array_pandora_machine_name[@]}; i++)); do
    array_maas_sysid+=($(sudo maas ${MAAS_USER} machines read | jq -r '.[] | select(.hostname == "'${array_pandora_machine_name[$i]}'") | .system_id'))
    msg "\t${array_maas_sysid[$i]}"
  done

  while true; do
    for ((i = 0; i < ${#array_maas_sysid[@]}; i++)); do
      MACHINE_STATE=$(sudo maas ${MAAS_USER} machine read ${array_maas_sysid[$i]} | jq -r '.status_name')
      if [ "${MACHINE_STATE}" == "Ready" ]; then
        msg "\t${array_pandora_machine_name[$i]} is ready"

        SYSTEM_ID=${array_maas_sysid[$i]}
        SET_ETH="enp5s0"
        SET_DHCP_IP="10.10.100.0/24"

        NIC_ID=$(sudo maas ${MAAS_USER} interfaces read ${SYSTEM_ID} | jq -r --arg name ${SET_ETH} '.[] | select(.name==$name) | .id')
        OLD_LINK_ID=$(sudo maas ${MAAS_USER} interfaces read ${SYSTEM_ID} | jq -r --arg name ${SET_ETH} '.[] | select(.name==$name) | .links[] | .id')
        msg "\t${array_pandora_machine_name[$i]} SYSTEM_ID=${SYSTEM_ID} NIC_ID=${NIC_ID} OLD_LINK_ID=${OLD_LINK_ID}"
        sudo maas ${MAAS_USER} interface unlink-subnet ${SYSTEM_ID} ${NIC_ID} id=${OLD_LINK_ID} >/dev/null

        SUBNET_ID=$(sudo maas ${MAAS_USER} subnets read | jq -r --arg name ${SET_DHCP_IP} '.[] | select(.name==$name) | .id')
        msg "\t${array_pandora_machine_name[$i]} SYSTEM_ID=${SYSTEM_ID} SUBNET_ID=${SUBNET_ID}"
        sudo maas ${MAAS_USER} interface link-subnet ${SYSTEM_ID} ${NIC_ID} mode=static subnet=${SUBNET_ID} ip_address=${array_pandora_machine_eth_ip[$i]} >/dev/null
        sudo maas ${MAAS_USER} machine deploy ${array_maas_sysid[$i]} \
          distro_series=focal \
          hwe_kernel=ga-20.04 \
          commissioning_distro_series=focal \
          commissioning_hwe_kernel=ga-20.04 \
          enable_ssh=true \
          user_data="#cloud-config" >/dev/null
      fi
      # Deploying
      if [ "${MACHINE_STATE}" == "Deploying" ]; then
        msg "\t\r${array_pandora_machine_name[$i]} is Deploying"
      fi
      # new
      if [ "${MACHINE_STATE}" == "New" ]; then
        msg "\t${array_pandora_machine_name[$i]} is new"
      fi
      # Commissioning
      if [ "${MACHINE_STATE}" == "Commissioning" ]; then
        msg "\t${array_pandora_machine_name[$i]} is Commissioning"
      fi
      # Deployed
      if [ "${MACHINE_STATE}" == "Deployed" ]; then
        msg "\t${array_pandora_machine_name[$i]} is deployed"
        array_machine_ready+=(${MACHINE_STATE})
      fi
      # Failed deployment
      if [ "${MACHINE_STATE}" == "Failed deployment" ]; then
        msg "\t${RED}${array_pandora_machine_name[$i]} is Failed deployment${NOFORMAT}"
        # sudo maas ${MAAS_USER} machine delete ${array_maas_sysid[$i]} > /dev/null
        # sudo ipmitool -I lanplus -H ${array_pandora_machine_ipmi_ip[$i]} -U ${array_pandora_machine_ipmi_user[$i]} -P ${array_pandora_machine_ipmi_pass[$i]} chassis power off
      fi
    done
    if [ ${#array_machine_ready[@]} -eq ${#array_maas_sysid[@]} ]; then
      break
    else
      # msg "\t${#array_machine_ready[@]} / ${#array_maas_sysid[@]}"
      array_machine_ready=()
      echo -n "."
      sleep 10
    fi
  done
}

function maas_setting() {
  msg "${GREEN}#-maas_settings${NOFORMAT}"
  maas_deploy_machines
}

function host_ssh_keygen() {
  msg "${GREEN}#-host_ssh_keygen${NOFORMAT}"

  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${array_pandora_machine_eth_ip[$i]}"
    ssh -o StrictHostKeyChecking=no ubuntu@${array_pandora_machine_eth_ip[$i]} "echo 'hello'"
  done
}

function rancher_status() {
  msg "${GREEN}#-rancher_status${NOFORMAT}"



  # API key for Rancher
  ENDPOINT="https://rancher.falinux.dev/v3"
  ACCESS_KEY="token-f827l"
  SECRET_KEY="5jz8fcf57jm52jjd5j7rcp7nvrfgr6fhq6dks8jv6jj6hr5znl42f4"
  BEARER_TOKEN="${ACCESS_KEY}:${SECRET_KEY}"

  CLUSTER_NAME="clone"
  CONFIG_NAME="config-${CLUSTER_NAME}"

  ${RANCHER_BIN} login ${ENDPOINT} --token ${BEARER_TOKEN}

  while true; do
    CLUSTER_STAT=$(${RANCHER_BIN} cluster ls | grep clone | awk '{ print $3 }')

    if [ "${CLUSTER_STAT}" == "active" ]; then
      msg "\t$CLUSTER_NAME is ${CLUSTER_STAT}"
      break
    fi
    sleep 5
  done

  ${RANCHER_BIN} kubectl config view >${HOME}/.kube/${CONFIG_NAME}

}

function k8s_install_certmanager() {
  msg "${GREEN}#-k8s_install_certmanager${NOFORMAT}"

  $RANCHER_BIN kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
}

function k8s_install_docker_registry() {
  msg "${GREEN}#-k8s_install_docker_registry${NOFORMAT}"

  cd ../../falinux-docker-registry/cli
  ./deploy-apply-kustomize.sh
  cd -

  # ../../bin/rancher namespace move docker c-mqq97:p-tlqlz
  #  ${RANCHER_BIN}
}

function k8s_install_glusterfs() {
  msg "${GREEN}#-k8s_install_glusterfs${NOFORMAT}"

  TOPOLOGY="topology-vm.json"

  cd k8s/glusterfs
  ./gk-deploy -gy ${TOPOLOGY}
  cd -

}

function k8s_uninstall_glusterfs() {
  msg "${GREEN}#-clean_storage${NOFORMAT} .. "

  SSH_USER="ubuntu"
  TOPOLOGY="topoogy-clone.json"

  cp ~/.kube/cofnig-clone ~/.kube/config
  cd ../falinux-glusterfs
  ./gk-deploy -gy ${TOPOLOGY} --abort
  cd -
}

function k8s_install_rancher_demo() {
  msg "${GREEN}#-k8s_install_rancher_demo${NOFORMAT}"

  $RANCHER_BIN kubectl apply -k k8s/rancher-demo/kustomize
}

function k8s_unnstall_rancher_demo() {
  msg "${GREEN}#-k8s_unnstall_rancher_demo${NOFORMAT}"

  $RANCHER_BIN kubectl delete -k k8s/rancher-demo/kustomize
}


##
# Print an error message to stderr.
function _error() {
  if [ $# -ne 1 ]; then
    printf "Expected 1 argument to \`_error\`, received %s.\\n" "$#" >&2
    exit 1
  fi

  local message
  message="$1"

  # printf "\e[2m\e[1mERROR\e[0m\e[2m: %s\e[0m\\n" "$message" >&2
  printf "\033[0;31m\e[1mERROR\e[0m\e[2m: %s\e[0m\\n" "$message" >&2
  # RED='\033[0;31m'
}

##
# Print a warning message to stderr.
_warning() {
  if [ $# -ne 1 ]; then
    _error "Expected 1 argument to \`_warning\`, received $#.\\n"
    return 1
  fi

  local message
  message="$1"

  printf "\e[2m\e[1mWARNING\e[0m\e[2m: %s\e[0m\\n" "$message" >&2
}

response() {
  if [ $# -eq 0 ]; then
    _error "Must submit at least 2 arguments to \`response\` function for IO."
    return 1
  elif [ $# -gt 2 ]; then
    _warning "received >2 arguments at response function, ignoring extra arguments"
  fi

  question="$1"
  default="$2"

  read -r -p "$question" var
  if [ "$var" ]; then
    printf "%s" "$var"
  else
    if [ "$default" ]; then
      _warning "Defaulting to $default"
    else
      _warning "Attempted to default, but no value given, returning \"\""
    fi
    printf "%s" "$default"
  fi

  return 0
}

##
# Switch rancher cluster contexts.
rancher_switch_cluster() {
  local cluster="$1"

  printf "Info: Attempting to create ~/.kube/config for cluster \"%s\"\\n" "$cluster"

  if ! ./bin/rancher clusters kf "$cluster" >config.new; then
    if [ -f config.new ]; then rm config.new; fi
    exit 1
  fi

  # Flatten new kubeconfig into existing config and clean up.
  cp "$HOME"/.kube/config "$HOME"/.kube/config.bak
  KUBECONFIG=config.new:"$HOME"/.kube/config.bak kubectl config view --flatten >"$HOME"/.kube/config &&
    rm "$HOME"/.kube/config.bak config.new &&
    printf "Info: Successfully switched context to cluster \"%s\"\\n" "$cluster"
}

DEFAULT_CLUSTER="${3:-development}"

rancher_select_cluster() {
  local cluster _cluster i n clusters selected_cluster

  mapfile -t clusters < <(./bin/rancher clusters ls --format "{{ .Cluster.Name }}")
  clusters+=("all")
  i=1
  n="${#clusters[@]}"

  while true; do
    printf "Select a cluster:\\n\\n"
    for cluster in "${clusters[@]}"; do
      printf "(%s) %s\\n" "$i" "$cluster"
      ((i += 1))
    done | column -t && printf "\\n"

    selected_cluster="$(response "Select a cluster (by name or index): " "${DEFAULT_CLUSTER}")"

    # Ensure this cluster is in the list (slow, linear search), either by index or name, and call a context switch.
    i=1
    for cluster in "${clusters[@]}"; do
      if [ "$selected_cluster" = "$cluster" ]; then
        if [ "$selected_cluster" != "all" ]; then
          rancher_switch_cluster "$selected_cluster"
        else
          # Loop over all clusters and merge their configs to a dev's local kubeconfig, defaulting to ${DEFAULT_CLUSTER}.
          for _cluster in "${clusters[@]}"; do
            if [ "$_cluster" != "all" ]; then
              rancher_switch_cluster "$_cluster"
            fi
          done
          kubectl config use-context "${DEFAULT_CLUSTER}"
        fi
        return 0
      elif [ "$selected_cluster" = "$i" ]; then
        if [ "${clusters[$((i - 1))]}" != "all" ]; then
          rancher_switch_cluster "${clusters[$((i - 1))]}"
        else
          for _cluster in "${clusters[@]}"; do
            if [ "$_cluster" != "all" ]; then
              rancher_switch_cluster "$_cluster"
            fi
          done
          kubectl config use-context "${DEFAULT_CLUSTER}"
        fi
        return 0
      elif [ "$i" -eq "$n" ]; then
        _error "Cluster \"$selected_cluster\" does not exist, try again"
        i=1
        break
      fi
      ((i += 1))
    done
  done
}

function k8s_setting() {
  # sleep 20
  rancher_select_cluster
  k8s_install_metallb
  # k8s_uninstall_metallb
  # k8s_install_certmanager
  # k8s_install_rancher_demo
  # k8s_unnstall_rancher_demo
  # k8s_install_glusterfs
  # k8s_install_gitlab
  # k8s_uninstall_gitlab
  # k8s_install_docker_registry
  # k8s_install_rancher_demo

}

function k8s_install_metallb () {
  msg "${GREEN}#-k8s_install_metallb${NOFORMAT}"

  $RANCHER_BIN kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
  $RANCHER_BIN kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
  # $RANCHER_BIN kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

  $RANCHER_BIN kubectl apply -f k8s/metallb/configmap.yaml

  NAMESPACE="metallb-system"

  # $RANCHER_BIN project create ${NAMESPACE}
  $RANCHER_BIN namespace move ${NAMESPACE} $($RANCHER_BIN project ls --format '{{.Project.ID}} {{.Project.Name}}' | grep ${NAMESPACE} | awk '{ print $1 }')

}

function k8s_uninstall_metallb () {
  msg "${GREEN}#-k8s_uninstall_metallb${NOFORMAT}"

  $RANCHER_BIN kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
  $RANCHER_BIN kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
  # $RANCHER_BIN kubectl delete secret -n metallb-system memberlist
  $RANCHER_BIN kubectl delete -f k8s/metallb/configmap.yaml

  NAMESPACE="metallb-system"
  $RANCHER_BIN project rm  $($RANCHER_BIN project ls --format '{{.Project.ID}} {{.Project.Name}}' | grep ${NAMESPACE} | awk '{ print $1 }')

}

function k8s_install_gitlab() {
  msg "${GREEN}#-k8s_install_gitlab${NOFORMAT}"

  # $RANCHER_BIN project create gitlab
  # $RANCHER_BIN namespace create gitlab
  $RANCHER_BIN namespace move gitlab $($RANCHER_BIN project ls --format '{{.Project.ID}} {{.Project.Name}}' | grep gitlab | awk '{ print $1 }')


  $RANCHER_BIN kubectl apply -k k8s/gitlab/kustomize/gitlab
  $RANCHER_BIN kubectl apply -k k8s/gitlab/kustomize/postgresql
  $RANCHER_BIN kubectl apply -k k8s/gitlab/kustomize/redis

}

function k8s_uninstall_gitlab () {
  msg "${GREEN}#-k8s_uninstall_gitlab${NOFORMAT}"

  $RANCHER_BIN kubectl delete -k k8s/gitlab/kustomize/gitlab
  $RANCHER_BIN kubectl delete -k k8s/gitlab/kustomize/postgresql
  $RANCHER_BIN kubectl delete -k k8s/gitlab/kustomize/redis

  $RANCHER_BIN project rm  $($RANCHER_BIN project ls --format '{{.Project.ID}} {{.Project.Name}}' | grep gitlab | awk '{ print $1 }')

}

function delete_rancher_cluser() {
  msg "${GREEN}#-delete_rancher_cluser${NOFORMAT}"

  RANCHER_VERSION="v2.3.2"
  RANCHER_OS="linux-amd64"
  RANCHER_PATH="../bin/"
  RANCHER_BIN="${RANCHER_PATH}rancher-${RANCHER_VERSION}-${RANCHER_OS}"

  # API key for Rancher
  ENDPOINT="https://rancher.falinux.dev/v3"
  ACCESS_KEY="token-f827l"
  SECRET_KEY="5jz8fcf57jm52jjd5j7rcp7nvrfgr6fhq6dks8jv6jj6hr5znl42f4"
  BEARER_TOKEN="${ACCESS_KEY}:${SECRET_KEY}"

  CLUSTER_NAME="clone"
  CONFIG_NAME="config-${CLUSTER_NAME}"

  ${RANCHER_BIN} login ${ENDPOINT} --token ${BEARER_TOKEN}
  ${RANCHER_BIN} cluster delete ${CLUSTER_NAME}

}

function clean_storage() {
  msg "${GREEN}#-clean_storage${NOFORMAT} .. "

  SSH_USER="ubuntu"

  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${array_pandora_machine_eth_ip[$i]}"
    ssh -o StrictHostKeyChecking=no ubuntu@${array_pandora_machine_eth_ip[$i]} "echo 'hello'"
  done
  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    #    scp ${DOCKER_INSTALL_SCRIPT} ${SSH_USER}@${array_pandora_machine_eth_ip[$i]}:~/
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'docker stop $(sudo docker ps -aq)'
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'docker rm $(sudo docker ps -aq)'
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'sudo vgremove --force $(sudo vgs | grep vg_ | cut -d " " -f3)'
  done
}

function uninstall_rancher() {
  msg "${GREEN}#-uninstall_rancher${NOFORMAT}"
  delete_rancher_cluser
  clean_storage
}

function infiniband_local_install_driver() {
  msg "${GREEN}#-infiniband_local_install_driver${NOFORMAT}"

  MLNX_OFED_LINUX_NAME="MLNX_OFED_LINUX-5.4-3.6.8.1-ubuntu20.04-x86_64.iso"
  NET_CONFIG_FILENAME="51-ib-config.yaml"
  IB_INTERFACE_NAME="ibp175s0"
  SSH_USER='ubuntu'

  mkdir -p ~/mnt/
  sudo mount -o rw,loop ${MLNX_OFED_LINUX_NAME} ~/mnt/
  cd ~/mnt && sudo ./mlnxofedinstall --all --force

  sudo umount ~/mnt/
  rm -rf ~/mnt/
  sudo /etc/init.d/openibd restart

  cat <<EOF >${NET_CONFIG_FILENAME}
network:
    ethernets:
        ${IB_INTERFACE_NAME}:
            addresses: [${array_pandora_machine_ib_ip[$i]}/24]
    version: 2
EOF

  sudo mv ${NET_CONFIG_FILENAME} /etc/netplan/
  sudo systemctl stop opensm
  sudo /etc/init.d/openibd restart
  sudo systemctl start opensm
  sudo netplan apply

}

function infiniband_install_driver() {
  msg "${GREEN}#-infiniband_install_driver${NOFORMAT}"

  MLNX_OFED_LINUX_NAME="MLNX_OFED_LINUX-5.4-3.6.8.1-ubuntu20.04-x86_64.iso"
  SSH_USER='ubuntu'

  msg "${GREEN}#-scp file to remote host${NOFORMAT} .. "
  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    msg "\t ${BLUE}##-${array_pandora_machine_eth_ip[$i]}${NOFORMAT}"
    if [ -f ${MLNX_OFED_LINUX_NAME} ]; then
      scp ${MLNX_OFED_LINUX_NAME} ${SSH_USER}@${array_pandora_machine_eth_ip[$i]}:~/
      ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'mkdir -p ~/mnt/'
      ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo mount -o rw,loop ${MLNX_OFED_LINUX_NAME} ~/mnt/"
      ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'cd ~/mnt && sudo ./mlnxofedinstall --all --force' &
    fi
  done

  wait

  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'sudo umount ~/mnt/'
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} 'rm -rf ~/mnt/'
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo /etc/init.d/openibd restart"
  done

}

function infiniband_set_netplan_config() {
  msg "${GREEN}#-infiniband_set_netplan_config${NOFORMAT}"

  NET_CONFIG_FILENAME="51-ib-config.yaml"
  IB_INTERFACE_NAME="ibp175s0"

  msg "${BLUE}##-set_network_config"
  msg "${BLUE}###-copy network config file to remote host${NOFORMAT} .."
  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    msg "\t ${BLUE}##-${array_pandora_machine_eth_ip[$i]}${NOFORMAT}"
    cat <<EOF >${NET_CONFIG_FILENAME}
network:
    ethernets:
        ${IB_INTERFACE_NAME}:
            addresses: [${array_pandora_machine_ib_ip[$i]}/24]
    version: 2
EOF
    scp ${NET_CONFIG_FILENAME} ${SSH_USER}@${array_pandora_machine_eth_ip[$i]}:~/
  done

  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo mv ${NET_CONFIG_FILENAME} /etc/netplan/"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo systemctl stop opensm"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo /etc/init.d/openibd restart"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo systemctl start opensm"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo netplan apply"
  done

  sleep 10

  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    #    ssh  ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo ibportstate -G $(ibstat | grep Node | cut -d ':' -f 2) 1 query"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "ip a show dev ${IB_INTERFACE_NAME}"
  done

  for ((i = 0; i < ${#array_pandora_machine_ib_ip[@]}; i++)); do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${array_pandora_machine_ib_ip[$i]}"
    ssh -o StrictHostKeyChecking=no ubuntu@${array_pandora_machine_ib_ip[$i]} "echo 'hello'"
  done
}

function infinibnad_setting() {
  msg "${GREEN}#-infinibnad_setting${NOFORMAT}"
  infiniband_local_install_driver
  infiniband_install_driver
  infiniband_set_netplan_config
}

# MAAS 를 통해서 네트워크 정보를 얻어 오는 함수
function get_maas_network_info() {
  msg "${GREEN}#-get_maas_network_info${NOFORMAT}"

  sudo maas ${MAAS_USER} subnets read | jq -r '.[] | .cidr' >maas_network_info.txt

  # maas_network_info.txt 파일을 읽어서 array_maas_network_cidr 배열에 넣는다.
  mapfile -t array_maas_network_cidr <maas_network_info.txt

  # array_maas_network_cidr 배열의 크기를 구한다.
  array_maas_network_cidr_size=${#array_maas_network_cidr[@]}

  # array_maas_network_cidr 배열의 크기만큼 반복한다.
  for ((i = 0; i < ${array_maas_network_cidr_size}; i++)); do
    # array_maas_network_cidr 배열의 값을 출력한다.
    msg "\t${array_maas_network_cidr[$i]}"
  done

  # maas_network_info.txt 파일을 삭제한다.
  rm -rf maas_network_info.txt
}

# MAAS 로 hostname, systemd_id, status 얻어오는 함수
function get_maas_machines_info() {
  msg "${GREEN}#-get_maas_machines_info${NOFORMAT}"

  # MAAS로부터 정보를 얻어와 maas_machines_info.json 파일에 저장
  sudo maas ${MAAS_USER} machines read | jq -r '.[] | [.hostname, .system_id, .status_name, .ip_addresses[]] | @tsv' >maas_machines_info.json

  # 2차원 배열을 선언하고 초기화
  declare -a machines_info=()

  # JSON 파일을 읽어와 2차원 배열에 추가
  while IFS=$'\t' read -r hostname system_id status ipaddress; do
    machines_info+=("$hostname" "$system_id" "$status" "$ipaddress")
  done <maas_machines_info.json

  # 2차원 배열 출력
  for ((i = 0; i < ${#machines_info[@]}; i += 4)); do
    # hostname 이 vm* 으로 표현되는 것만 출력
    if [[ ${machines_info[i]} == vm[0-9] ]]; then
      msg "\t${machines_info[i]} ${machines_info[i + 1]} ${machines_info[i + 2]} ${machines_info[i + 3]}"
    fi
    # printf "Hostname: %s\n" "${machines_info[i]}"
    # printf "System ID: %s\n" "${machines_info[i + 1]}"
    # printf "Status: %s\n" "${machines_info[i + 2]}"
    # echo "--------------------------------------------"
  done

  # maas_machines_info.json 파일을 삭제
  # rm -rf maas_machines_info.json
}

declare -a vm_machines_info=(
  "vm00" "10.10.100.87"
  "vm01" "10.10.100.88"
  "vm02" "10.10.100.89"
)

function install_docker() {
  msg "${GREEN}#-install_docker${NOFORMAT}"

  DOCKER_INSTALL_SCRIPT="docker_install.sh"
  DOCKER_USER_NAME="ubuntu"
  SSH_USER="ubuntu"

  cat <<EOF >${DOCKER_INSTALL_SCRIPT}
#!/bin/bash
# install docker on ubuntu 20.04
sudo systemctl stop ufw
sudo systemctl disable ufw
curl -ksfsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ${DOCKER_USER_NAME}
sudo systemctl enable docker
sudo systemctl start docker
EOF
  chmod +x ${DOCKER_INSTALL_SCRIPT}

  chmod +x ${DOCKER_INSTALL_SCRIPT}
  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    msg "\t${BLUE}array_pandora_machine_eth_ip ${array_pandora_machine_eth_ip[$i]}${NOFORMAT}"
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${array_pandora_machine_eth_ip[$i]}"
    ssh -o StrictHostKeyChecking=no ubuntu@${array_pandora_machine_eth_ip[$i]} "echo 'hello'"
    scp ${DOCKER_INSTALL_SCRIPT} ${SSH_USER}@${array_pandora_machine_eth_ip[$i]}:~/
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} " sudo sed -i 's/archive.ubuntu.com/ftp.kaist.ac.kr/g' /etc/apt/sources.list"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "sudo ./${DOCKER_INSTALL_SCRIPT}"
  done

  rm -rf ${DOCKER_INSTALL_SCRIPT}

}

function rancher_setting() {
  rancher_login
  rancher_create_cluster
  add_node_to_cluster
  wait_rancher_cluster
}

function wait_rancher_cluster() {
  msg "${GREEN}#-wait_rancher_cluster${NOFORMAT}"

  output=$(./bin/rancher cluster ls --format "{{ .Cluster.Name }} {{ .Cluster.State }}")

  cluster_name=()
  cluster_state=()

  # Loop through each line of the output
  while IFS= read -r line; do
    # Split each line by space and extract the name and state
    read -r name state <<<"$line"

    # Add the name and state to their respective arrays
    cluster_names+=("$name")
    cluster_states+=("$state")
  done <<<"$output"

  for ((i = 0; i < ${#cluster_name[@]}; i++)); do
    msg "\t${BLUE}cluster_name ${cluster_name[$i]} cluster_state ${cluster_state[$i]}${NOFORMAT}"
    if [ "${cluster_state[$i]}" == "active" ]; then
      msg "\t${BLUE}cluster_name ${cluster_name[$i]} cluster_state ${cluster_state[$i]}${NOFORMAT}"
      break
    fi
  done

}

# rancher login
function rancher_login() {
  msg "${GREEN}#-rancher_login${NOFORMAT}"

  # if command -v pass >/dev/null && [ -z "$_RANCHER_TOKEN" ]; then
  #   _RANCHER_TOKEN="$(pass show rancher-token)"
  # elif [ -z "$_RANCHER_TOKEN" ]; then
  #   _error "must set RANCHER_TOKEN environment variable or set up pass"
  #   exit 1
  # fi

  while [ -z "$_RANCHER_TOKEN" ]; do
    if command -v pass >/dev/null; then
      _RANCHER_TOKEN="$(pass show rancher-token)"
    else
      _error "Pass is not installed. Please set the _RANCHER_TOKEN environment variable."
      exit 1
    fi
  done

  echo 1 | ./bin/rancher login -t ${_RANCHER_TOKEN} ${_RANCHER_URL} >>/dev/null
}

# rancher create cluster
function rancher_create_cluster() {
  msg "${GREEN}#-rancher_create_cluster${NOFORMAT}"

  # user input cluster name
  read -p "Enter cluster name: " _CLUSTER_NAME

  # 클러스터 생성
  ./bin/rancher cluster create ${_CLUSTER_NAME} >>/dev/null

  # # 노드를 추가할 클러스터 선택
  # ../bin/rancher context switch

  # # 클러스터 선택 확인
  # SELECT_CLUSTER=$(../bin/rancher cluster ls | grep '*' | awk '{ print $4 }')
  # # ../bin/rancher cluster ls | grep '*' | awk '{ print $4 }'
  # if [ "${SELECT_CLUSTER}" == "${_CLUSTER_NAME}" ]; then
  #   msg "\tselect cluster ${SELECT_CLUSTER}"
  # else
  #   _error "select cluster ${SELECT_CLUSTER}"
  #   exit 1
  # fi

  # SSH_USER="ubuntu"

  # # 클러스터에 노드 추가
  # for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
  #   msg "\t${BLUE}##-${array_pandora_machine_eth_ip[$i]}${NOFORMAT}"
  #   ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "$(../bin/rancher cluster add-node --etcd --controlplane --worker ${_CLUSTER_NAME})" &
  #   # ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} $($RANCHER_BIN cluster add-node ${OPTS} ${CLUSTER_NAME}) &
  # done

  # wait

}

# add node to cluster
function add_node_to_cluster() {
  msg "${GREEN}#-add_node_to_cluster${NOFORMAT}"

  SSH_USER="ubuntu"

  ./bin/rancher context switch

  # 클러스터 선택 확인
  SELECT_CLUSTER=$(./bin/rancher cluster ls | grep '*' | awk '{ print $4 }')
  # ../bin/rancher cluster ls | grep '*' | awk '{ print $4 }'

  # print selected cluster
  msg "SELECT_CLUSTER: ${SELECT_CLUSTER}"

  # user select yes or no
  read -p "Do you want to add node to cluster? (y/n) " _ANSWER

  # 만약 y 이면 계속진행, 아니면 종료
  if [ "${_ANSWER}" == "y" ]; then
    msg "\tcontinue"
  else
    exit 1
  fi

  # 클러스터에 노드 추가
  for ((i = 0; i < ${#array_pandora_machine_eth_ip[@]}; i++)); do
    msg "\t${BLUE}##-${array_pandora_machine_eth_ip[$i]}${NOFORMAT}"
    ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} "$(./bin/rancher cluster add-node --etcd --controlplane --worker ${SELECT_CLUSTER})"
    # ssh ${SSH_USER}@${array_pandora_machine_eth_ip[$i]} $($RANCHER_BIN cluster add-node ${OPTS} ${CLUSTER_NAME}) &
  done

}

#-------------------------------------------------------------------------------
function main() {
  msg "${ORANGE}#-Start Script.${NOFORMAT}"
  # start time
  start_time=$(date +%s)
  #-------------------------------------------------------------------------------
  # 잘 동작하는 셋
  pandora_machines_info_split
  # maas_setting
  # install_docker
  # rancher_setting
  k8s_setting
  #-------------------------------------------------------------------------------
  # test set
  #  install_redmine
  #-------------------------------------------------------------------------------
  # end time
  end_time=$(date +%s)
  # elapsed time
  elapsed_time=$(($end_time - $start_time))
  elapsed_time_min=$(($elapsed_time / 60))
  elapsed_time_sec=$(($elapsed_time % 60))
  msg "${YELLOW}#-Elapsed time : ${elapsed_time_min}m ${elapsed_time_sec}s${NOFORMAT}"
  msg "${ORANGE}#-End Script.${NOFORMAT}"
}

main

exit
