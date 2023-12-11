import json
from os import close, read
import time
import getpass
import subprocess
from termcolor import colored

from tqdm import tqdm

import maas.client
from maas.client import login
from maas.client.enum import NodeStatus
from maas.client.enum import LinkMode
from maas.client.utils.maas_async import asynchronous

import asyncio

# https://maas.github.io/python-libmaas/

cluster_info = {}
machine_to_system_id = {}  # 머신 이름을 시스템 ID로 매핑하는 딕셔너리


def get_cluster_info(cluster_config_file):
    print(colored("#-get_cluster_info", "green"))

    global cluster_info

    try:
        # JSON 파일 열기
        with open(cluster_config_file, "r") as f:
            cluster_info = json.load(f)
            print_cluster_info()

    except json.JSONDecodeError as e:
        print(f"cluster info not parse: {e}")


def get_maas_machine_info():
    """
    MAAS로 생성된 머신 정보를 읽어오는 함수
    """
    print(colored("#-get_maas_machine_info", "green"))

    global cluster_info

    maas_info = cluster_info.get("maas_infos", {})
    nodes = cluster_info.get("nodes", [])

    # MAAS command execute
    maas_cmd = ["sudo", "maas", maas_info["maas_user"], "machines", "read"]

    result = subprocess.run(
        maas_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )


def print_cluster_info():
    """
    클러스터 정보 출력 함수
    """
    print(colored("#-print_cluster_info", "green"))

    global cluster_info
    cluster_name = cluster_info.get("cluster_name", "")
    nodes = cluster_info.get("nodes", [])

    colume_length = 15

    print(f"cluster_name =", colored(cluster_name.strip(), "blue"))
    print(
        "hostname".ljust(colume_length),
        "ipmi_mac".ljust(colume_length),
        "ipmi_ip".ljust(colume_length),
        "eth_ip".ljust(colume_length),
        "ib_ip".ljust(colume_length),
        "ipmi_user".ljust(colume_length),
        "ipmi_pass".ljust(colume_length),
    )

    for node in nodes:
        hostname = node.get("hostname", "")
        ipmi_mac = node.get("ipmi_mac", "")
        ipmi_ip = node.get("ipmi_ip", "")
        eth_ip = node.get("eth_ip", "")
        ib_ip = node.get("ib_ip", "")
        ipmi_user = node.get("ipmi_user", "")
        ipmi_pass = node.get("ipmi_pass", "")

        tsv_data = "\t".join(
            [
                hostname.ljust(colume_length),
                ipmi_mac.ljust(colume_length),
                ipmi_ip.ljust(colume_length),
                eth_ip.ljust(colume_length),
                ib_ip.ljust(colume_length),
                ipmi_user.ljust(colume_length),
                ipmi_pass.ljust(colume_length),
            ]
        )

        print(tsv_data)


def maas_login():
    print(colored("#-maas_login", "green"))

    # MAAS 서버에 로그인
    maas_url = "https://maas.falinux.dev:5443/MAAS/api/2.0/"
    maas_username = "falinux"

    # pass show falinux-pass is not null
    falinux_pass = subprocess.run(
        ["pass", "show", "falinux-pass"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    falinux_pass = falinux_pass.stdout.strip()

    if falinux_pass:
        maas_password = falinux_pass
    else:
        maas_password = getpass.getpass("Enter MAAS password: ")

    maas_client = login(maas_url, username=maas_username, password=maas_password)

    return maas_client


def get_maas_info_nodes():
    print(colored("#-get_maas_info_nodes", "green"))

    maas_client = maas_login()

    # 현재 MAAS 서버에 등록된 노드 목록 가져오기
    nodes = maas_client.machines.list()

    for node in nodes:
        print(f"Hostname: {node.hostname}")

    return nodes


def get_cluster_info_nodes():
    print(colored("#-get_cluster_info_nodes", "green"))

    global cluster_info

    nodes = cluster_info.get("nodes", [])

    for node in nodes:
        print(f"Hostname: {node.get('hostname', '')}")

    return nodes


def create_maas_vm_machine(cluster_info_nodes, maas_info_nodes):
    print(colored("#-create_maas_vm_machine", "green"))

    for cluster_info_node in cluster_info_nodes:
        cluster_hostname = cluster_info_node.get("hostname", "")
        fount = False
        # print(f"cluster_hostname: {cluster_hostname}")

        for maas_info_node in maas_info_nodes:
            maas_hostname = maas_info_node.hostname
            if maas_hostname == cluster_hostname:
                # print(f"Machine {cluster_hostname} already created. Skipping...")
                fount = True
                break

        if not fount:
            print(f"Machine {cluster_hostname} not created. Create...")
            maas_cmd = [
                "sudo",
                "maas",
                cluster_info_node["maas_user"],
                "vm-host",
                "compose",
                str(
                    cluster_info_node["vm_machine_num"]
                ),  # 수정: "machine_num" 대신 "vm_machine_num" 사용
                f"cores={cluster_info_node['vm_cores']}",
                f"memory={cluster_info_node['vm_memory']}",
                f"hostname={cluster_info_node['hostname']}",  # 수정: "hostname"에 대한 키 접근을 수정
            ]

            # Add storage if available
            storage_sizes = []

            # Add boot-disk if available
            if "vm_boot_disk" in cluster_info_node:
                storage_sizes.append(str(cluster_info_node["vm_boot_disk"]))

            # Add storage if available
            if "vm_storage" in cluster_info_node:
                storage_sizes.extend(
                    [str(size["size"]) for size in cluster_info_node["vm_storage"]]
                )

                ## # Join storage sizes with commas
            storage_option = ",".join(storage_sizes)

            # # Append storage option to maas_cmd
            maas_cmd.append(f"storage={storage_option}")

            result = subprocess.run(
                maas_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            )


async def deploy_maas_vm_machine(cluster_info_nodes, maas_info_nodes):
    print(colored("#-deploy_maas_vm_machine", "green"))

    client = await maas_login()

    all_machine = await client.machines.list()
    ready_machine = [
        machine for machine in all_machine if machine.status in [NodeStatus.READY, NodeStatus.COMMISSIONING]
    ]

    # wiat for until all machine are READY
    print(colored("wiat for until all machine are ready", "blue"))

    # tqdm: progress bar
    progress_bar = tqdm(total=len(ready_machine))
    while (len(ready_machine)) > 0:
        await asyncio.sleep(5)
        progress_bar.update(0.001)
        for machine in ready_machine:
            await machine.refresh()
            if machine.status in [NodeStatus.COMMISSIONING, NodeStatus.TESTING]:
                continue
            elif machine.status == NodeStatus.READY:
                # print(f"Machine {machine.hostname} is ready. Deploying...")
                # print(f"machine.hostname: {machine.hostname}")
                # cluster_info_nodes 의 hostname 과 machine.hostname 이 같은 경우 eth_ip 를 가져온다.
                cluster_eth_ips = [
                    node.get("eth_ip", "")
                    for node in cluster_info_nodes
                    if node.get("hostname", "") == machine.hostname
                ]
                # print(f"cluster_eth_ips: {cluster_eth_ips}")

                # eth_subnet 을 가져온다.
                cluster_eth_subnet = [
                    node.get("eth_subnet", "")
                    for node in cluster_info_nodes
                    if node.get("hostname", "") == machine.hostname
                ]
                # print(f"cluster_eth_subnet: {cluster_eth_subnet}")

                # get subnet id
                subnet = await client.subnets.get(cluster_eth_subnet[0])
                # print(f"subnet.id: {subnet.id}")

                # eth_interface 을 가져온다.
                cluster_eth_interface = [
                    node.get("eth_interface", "")
                    for node in cluster_info_nodes
                    if node.get("hostname", "") == machine.hostname
                ]
                # print(f"cluster_eth_interface: {cluster_eth_interface}")

                # get eth interface
                eth_interface = machine.interfaces.get_by_name(cluster_eth_interface[0])
                await eth_interface.disconnect()
                await eth_interface.links.create(
                    mode=LinkMode.STATIC,
                    ip_address=cluster_eth_ips[0],
                    subnet=subnet.id,
                    force=True,
                )

                await machine.deploy()
                ready_machine.remove(machine)
                progress_bar.update(1)
            else:
                progress_bar.update(0.01)

    deployed_machine = [
        machine for machine in all_machine if machine.status == NodeStatus.DEPLOYING
    ]

    # wait for until all machine are deployed
    print(colored("wait for until all machine are deployed", "blue"))
    progress_bar = tqdm(total=len(deployed_machine))
    while (len(deployed_machine)) > 0:
        await asyncio.sleep(5)
        progress_bar.update(0.001)
        for machine in deployed_machine:
            await machine.refresh()
            if machine.status in [NodeStatus.DEPLOYING]:
                continue
            elif machine.status == NodeStatus.DEPLOYED:
                # print(f"Machine {machine.hostname} is deployed.")
                deployed_machine.remove(machine)
                progress_bar.update(1)


if __name__ == "__main__":
    print(colored("#-main", "green"))
    config_file = "config/cluster-vm-rancher.json"

    get_cluster_info(config_file)

    cluster_info_nodes = get_cluster_info_nodes()
    maas_info_nodes = get_maas_info_nodes()

    create_maas_vm_machine(cluster_info_nodes, maas_info_nodes)

    # asyncio.run()을 사용하여 비동기 코드 실행
    asyncio.run(deploy_maas_vm_machine(cluster_info_nodes, maas_info_nodes))
