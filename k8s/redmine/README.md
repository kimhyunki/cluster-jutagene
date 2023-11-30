# docker-compose 설치

https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04

    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    sudo chmod +x /usr/local/bin/docker-compose

    docker-compose --version

# docker build

cd docker
docker-compose build or ./deploy-kustomize.sh

# 클론 클러스터의 redmine 데이터 가져오기

## 클론 클러스터 glusterfs 접근

- ssh 를 통하여 main 클러스터로 이동한다.

- glusterfs 디렉토리로 이동한다.

- mkdir glusterfs

### glusterfs 를 접근하기위한 정보 도출

    % kubectl get nodes --kubeconfig ~/.kube/config-clone -o wide | awk -v OFS='\t\t' '{print $1,$6}' 
    NAME            INTERNAL-IP
    nb-lg-white     192.168.10.133
    storagecl       192.168.10.121
    tyan03          192.168.10.122
    tyan04          192.168.10.123
    xs-safe-01      192.168.10.132
    xs-work-02      192.168.10.131

    % kubectl get nodes --kubeconfig ~/.kube/config-main -o wide | awk -v OFS='\t\t' '{print $1,$6}'
    NAME            INTERNAL-IP
    r0-s03          192.168.10.113
    r0-s04          192.168.10.114
    r0-s05          192.168.10.115
    r1-s01          192.168.10.101
    r1-s02          192.168.10.102
    r1-s03          192.168.10.103

### 쿠버네티스 서비스의 레드마인의 데이터를 가져오기위한 정보

- 레드마인의 pv 정보를 가져온다.

- 클론 클러스터의 데이저 저장된 것을 가져온다

    /bitnami/redmine/files

- clone cluster 

    % sudo mount -t glusterfs 192.168.10.133:vol_1a5c8c3972ca4184f81c19020c43824d cluster-clone/

- main cluster 

    % sudo mount -t glusterfs 192.168.10.113:vol_97754e3ab5d22fc37bd4325970e90e72 clone/

- 메인 클러스터 마운트 정보
  * 파싱하는 정보를 만든다. 

    % kubectl --kubeconfig ~/.kube/config-main -n redmine describe pv pvc-fb23af8f-7309-4fd8-a0ea-70b773a2a7d7 

    % kubectl --kubeconfig ~/.kube/config-main -n redmine get ep glusterfs-dynamic-fb23af8f-7309-4fd8-a0ea-70b773a2a7d7

