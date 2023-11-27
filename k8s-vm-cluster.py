import json
import subprocess
import time
from termcolor import colored


import asyncio

import maas.client

from maas.client import connect
from maas.client.enum import NodeStatus
# from maas.client.utils.async import asynchronous

from maas.client import login

import getpass


# https://maas.github.io/python-libmaas/

cluster_info = {}
machine_to_system_id = {}  # 머신 이름을 시스템 ID로 매핑하는 딕셔너리

def get_machine_status(system_id):
    """
    머신의 상태를 조회하는 함수
    """
    print(colored("#-get_machine_status", 'green'))

    global cluster_info

    maas_info = cluster_info.get("maas_infos", {})

    # MAAS command execute
    maas_cmd = [
        "sudo",
        "maas", 
        maas_info["maas_user"],
        "machine",
        "read",
        system_id
    ]

    result = subprocess.run(maas_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    if "status_name" in result.stdout:
        try:
            # JSON 데이터 파싱
            data = json.loads(result.stdout)

            # 상태 이름 추출
            status_name = data.get("status_name")

            print(f"Machine {system_id} status: {status_name}")
            return status_name
        except json.JSONDecodeError as e:
            print(f"Failed to parse JSON output: {e}")
    else:
        print(f"Failed to get machine {system_id} status. Error: {result.stderr}")

    return None

def maas_deploy_ubuntu(machine, system_id, nodes):
    """
    Ubuntu를 MAAS로 배포하는 함수
    """
    print(colored("#-maas_deploy_ubuntu", 'green'))

    global cluster_info

    # get nodes.get eth_interface
    for node in nodes:
        if node.get("hostname", '') == machine:
            eth_interface = node.get("eth_interface", '')

    # get nic_id
    nic_id = subprocess.run(
        ["sudo", "maas", maas_info["maas_user"], "interfaces", "read", system_id],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    ).stdout

    nic_id = json.loads(nic_id)[0]["id"]

    # get old_link_id
    old_link_id = subprocess.run(
        ["sudo", "maas", maas_info["maas_user"], "interface", "read", system_id, nic_id],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    ).stdout

    old_link_id = json.loads(old_link_id)["links"][0]["id"]

    print("nic_id: ", nic_id, "old_link_id: ", old_link_id)

    # # unlink old link
    # subprocess.run(
    #     ["sudo", "maas", maas_info["maas_user"], "interface", "unlink-subnet", system_id, nic_id, old_link_id],
    #     stdout=subprocess.PIPE,
    #     stderr=subprocess.PIPE,
    #     text=True
    # )

    # # get subnet_id
    # subnet_id = subprocess.run(
    #     ["sudo", "maas", maas_info["maas_user"], "subnets", "read"],
    #     stdout=subprocess.PIPE,
    #     stderr=subprocess.PIPE,
    #     text=True
    # ).stdout

    # subnet_id = json.loads(subnet_id)[0]["id"]

def maas_deploy_mahcine():
    """
    MAAS로 머신 배포 및 상태 확인 함수
    """
    print(colored("#-maas_deploy_machine", 'green'))

    global cluster_info
    global machine_to_system_id

    cluster_name = cluster_info.get("cluster_name", '')
    maas_info = cluster_info.get("maas_infos", {}) 
    nodes = cluster_info.get("nodes", [])

    # 머신 이름을 시스템 ID로 매핑하는 딕셔너리가 비어있으면 종료
    if not machine_to_system_id:
        print("No machines created. Exiting...")
        return

    # 머신 이름을 시스템 ID로 매핑하는 딕셔너리 출력
    print("Machine to System ID mapping:")
    for machine, system_id in machine_to_system_id.items():
        print(f"{machine} -> {system_id}")

    # endless loop to get machine status
    while True:
        all_deployed = True
        for machine, system_id in machine_to_system_id.items():
            machine_status = get_machine_status(system_id)
            if machine_status != "Deployed":
                all_deployed = False
            
            if machine_status == "Ready":
                maas_deploy_ubuntu(machine, system_id, nodes)

        if all_deployed:
            print("All machines deployed!")
            break

        time.sleep(10)



def get_cluster_info(cluster_config_file):
    print(colored("#-get_cluster_info", 'green'))

    global cluster_info

    try:
        # JSON 파일 열기
        with open(cluster_config_file, "r") as f:
            cluster_info = json.load(f)

    except json.JSONDecodeError as e:
        print(f"cluster info not parse: {e}")


def get_maas_machine_info():
    """
    MAAS로 생성된 머신 정보를 읽어오는 함수
    """
    print(colored("#-get_maas_machine_info", 'green'))

    global cluster_info

    maas_info = cluster_info.get("maas_infos", {})
    nodes = cluster_info.get("nodes", [])

    # MAAS command execute
    maas_cmd = [
        "sudo",
        "maas", 
        maas_info["maas_user"],
        "machines",
        "read"
    ]

    result = subprocess.run(maas_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def maas_create_vm_machines():
    """
    MAAS로 가상 머신을 생성하는 함수
    """
    print(colored("#-maas_create_vm_machines", 'green'))

    global cluster_info


    # 가상 머신이 생성되었는지 확인
    maas = subprocess.run(
        ["sudo", "maas", maas_info["maas_user"], "machines", "read"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    ).stdout

    maas = json.loads(maas).get("hostname", '')

    # cluster_info에서 maas_infos, nodes의 hostname 이 있는지 확인
    for node in nodes:
        if maas.find(node.get("hostname", '')) != -1:
            print(f"Machine {node.get('hostname', '')} already created. Skipping...")
            continue


    maas_info = cluster_info.get("maas_infos", {})
    nodes = cluster_info.get("nodes", [])

    for node in nodes:
        hostname = node.get("hostname", '')

        # MAAS command execute
        maas_cmd = [
            "sudo",
            "maas", 
            maas_info["maas_user"],
            "vm-host",
            "compose",
            str(maas_info["machine_num"]),
            f"cores={maas_info['vm_cores']}",
            f"memory={maas_info['vm_memory']}",
            f"hostname={hostname}"
        ]

        # Add storage if available
        storage_sizes = []

        # Add boot-disk if available
        if "vm_boot_disk" in maas_info:
            storage_sizes.append(str(maas_info['vm_boot_disk']))

        # Add storage if available
        if "vm_storage" in maas_info:
            storage_sizes.extend([str(size['size']) for size in maas_info['vm_storage']])

        # Join storage sizes with commas
        storage_option = ','.join(storage_sizes)

        # Append storage option to maas_cmd
        maas_cmd.append(f"storage={storage_option}")

        result = subprocess.run(maas_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout = result.stdout
        stderr = result.stderr

        if "system_id" in result.stdout:
            try:
                # JSON 데이터 파싱
                data = json.loads(result.stdout)

                # 시스템 ID 추출
                system_id = data.get("system_id")

                # 머신 이름과 시스템 ID를 매핑
                machine_to_system_id[hostname] = system_id

                print(f"Machine {hostname} created with System ID: {system_id}")
            except json.JSONDecodeError as e:
                print(f"Failed to parse JSON output: {e}")
        else:
            print(f"Failed to create machine {hostname}. Error: {result.stderr}")

def print_cluster_info():
    """
    클러스터 정보 출력 함수
    """
    print(colored("#-print_cluster_info", 'green'))

    global cluster_info
    cluster_name = cluster_info.get("cluster_name", '')
    nodes = cluster_info.get("nodes", [])

    colume_length = 15

    print(f"cluster_name =", colored(cluster_name.strip(), 'blue'))
    print("hostname".ljust(colume_length), "ipmi_mac".ljust(colume_length), "ipmi_ip".ljust(colume_length), \
            "eth_ip".ljust(colume_length), "ib_ip".ljust(colume_length), "ipmi_user".ljust(colume_length), \
                "ipmi_pass".ljust(colume_length))
        
    for node in nodes:
        hostname = node.get("hostname", '')
        ipmi_mac = node.get("ipmi_mac", '')
        ipmi_ip = node.get("ipmi_ip", '')
        eth_ip = node.get("eth_ip", '')
        ib_ip = node.get("ib_ip", '')
        ipmi_user = node.get("ipmi_user", '')
        ipmi_pass = node.get("ipmi_pass", '')

        tsv_data = "\t".join([hostname.ljust(colume_length), ipmi_mac.ljust(colume_length), ipmi_ip.ljust(colume_length), \
            eth_ip.ljust(colume_length), ib_ip.ljust(colume_length), ipmi_user.ljust(colume_length), \
                ipmi_pass.ljust(colume_length)])

        print(tsv_data)


def maas_login():
    """
    MAAS 로그인 함수
    """
    print(colored("#-maas_login", 'green'))

    client = maas.client.connect(
        url='https://maas.falinux.dev:5443/MAAS/api/2.0/', apikey="Q56LqWPL9uSdLqr2AK:Meufe85jeWLnCNvUy2:s64qkn4R69Q8CauHqPBRcJBgC6GpMbGX")

    # get a reference to self.
    myself = client.users.whoami()
    assert myself.is_admin, "%s is not an admin" % myself.username

    # check for a MAAS server capability.
    version = client.version.get()
    assert "devices-management" in version.capabilities

    # check the default os and distro seris for deployements.
    print(client.maas.get_default_os())
    print(client.maas.get_default_distro_series())

    # set the http proxy

    # allocate and deploy a machine
    # machine = client.machines.allocate()


    for machine in client.machines.list():
        print(repr(machine))
    
    # for devices in client.devices.list():
    #     print(repr(devices))
    
    # for rack_controller in client.rack_controllers.list():
    #     print(repr(rack_controller))
    
    # for region_controller in client.region_controllers.list():
    #     print(repr(region_controller))

    # for subnet in client.subnets.list():
    #     print(repr(subnet))

    # for fabric in client.fabrics.list():
    #     print(repr(fabric))


    # get a machine from its system_id
    # machine = client.machine.get(system_id="nmfw7h")

    machine.hostname = vm00
    machine.architecture = "amd64/generic"
    machine.save()


if __name__ == "__main__":
    print(colored("#-main", 'green'))
    config_file = "config/cluster-vm.json"


    # MAAS 서버에 로그인
    maas_url = "https://maas.falinux.dev:5443/MAAS/api/2.0/"
    maas_username = "falinux"

    # pass show falinux-pass is not null
    falinux_pass = subprocess.run(
        ["pass", "show", "falinux-pass"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    falinux_pass = falinux_pass.stdout.strip()

    if falinux_pass:
        maas_password = falinux_pass
    else:
        maas_password = getpass.getpass("Enter MAAS password: ")

    maas_client = login(maas_url, username=maas_username, password=maas_password)

    # 현재 MAAS 서버에 등록된 노드 목록 가져오기
    nodes = maas_client.machines.list()

    # 노드 목록 출력
    for node in nodes:
        # print(f"Hostname: {node.hostname}")
        # print(f"System ID: {node.system_id}")
        # print(f"Status: {NodeStatus(node.status).name}")
        if node.status == NodeStatus.READY.value:
            print(f"Hostname: {node.hostname}")
            machine = maas_client.machines.get(node.system_id)
            machine.deploy()
        if node.status == NodeStatus.ALLOCATED.value:
            machine = maas_client.machines.get(node.system_id)
            machine.deploy()



    # # 특정 노드의 상태 변경 (예: 배포 준비 상태로 변경)
    # node_id_to_deploy = "your-node-id-to-deploy"
    # node_to_deploy = maas_client.nodes.get(node_id_to_deploy)
    # if node_to_deploy:
    #     if node_to_deploy.status != NodeStatus.READY.value:
    #         print(f"Changing the status of Node {node_id_to_deploy} to READY")
    #         node_to_deploy.start()
    #     else:
    #         print(f"Node {node_id_to_deploy} is already in READY status.")
    # else:
    #     print(f"Node with ID {node_id_to_deploy} not found.")

    # # 노드 목록 다시 출력하여 변경된 상태 확인
    # nodes = maas_client.nodes.list()
    # for node in nodes:
    #     print(f"Node ID: {node.resource_id}")
    #     print(f"Status: {NodeStatus(node.status).name}")
    #     print("------")


    # get_cluster_info(config_file)

    # print_cluster_info()

    # maas_login()

    # get_maas_machine_info()

    # maas_create_vm_machines()

    # maas_deploy_machine()
