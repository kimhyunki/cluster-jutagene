import json
from shlex import join
# terminal color
from termcolor import colored

import subprocess

config_file = "config/cluster-vm.json"

def maas_create_vm_machines(nodes):
    print(colored("#-maas_create_vm_machines", 'green'))

    MAAS_USER="falinux"
    MACHINE_NUM="565"
    VM_CORES="4"
    VM_STORAGE="30,50"

    a = "16 * 1024"
    VM_MEMORY = eval(a)

    for node in nodes:
        hostname = node.get("hostname", '')

        # MAAS command execute
        maas_cmd = [
            "sudo",
            "maas",
            MAAS_USER,
            "vm-host",
            "compose",
            str(MACHINE_NUM),
            f"cores={VM_CORES}",
            f"memory={VM_MEMORY}",
            f"storage={VM_STORAGE}",
            f"hostname={hostname}"
        ]
        subprocess.run(maas_cmd)


try:
    # JSON 파일 열기
    with open(config_file, "r") as f:
        cluster_info = f.read()

    # dict to array
    cluster_info_list = []
    cluster_info_list.append(json.loads(cluster_info))

    # array to dict
    for cluster_info in cluster_info_list:
        cluster_name = cluster_info.get("cluster_name", '')
        node_count = cluster_info.get("node_count", 0)
        node_config = cluster_info.get("node_config", {})
        services = cluster_info.get("services", [])
        nodes = cluster_info.get("nodes", [])

        print(f"cluster_name =" , colored(cluster_name.strip(), 'blue'))
        # print(f"node_count =" , colored(node_count, 'blue'))
        # print(f"node_config =" , colored(node_config, 'blue'))
        # print(f"services =" , colored(services, 'blue'))
        # print(f"nodes: {nodes}")


        # define ljust value 15
        colume_length = 15
        # print culome name 
        print(\
            "hostname".ljust(colume_length), "ipmi_mac".ljust(colume_length), "ipmi_ip".ljust(colume_length), \
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

            # print tsv value
            tsv_data = "\t".join([hostname.ljust(colume_length), ipmi_mac.ljust(colume_length), ipmi_ip.ljust(colume_length), \
                eth_ip.ljust(colume_length), ib_ip.ljust(colume_length), ipmi_user.ljust(colume_length), \
                    ipmi_pass.ljust(colume_length)])
            print(tsv_data)
            
            # print node info sequentially value blue
            # print(\
            #     f"hostname =", colored(hostname.strip(), 'blue'), \
            #     f"ipmi_mac =", colored(ipmi_mac.strip(), 'blue'), \
            #     f"ipmi_ip =", colored(ipmi_ip.strip(), 'blue'), \
            #     f"eth_ip =", colored(eth_ip.strip(), 'blue'), \
            #     f"ib_ip =", colored(ib_ip.strip(), 'blue'), \
            #     f"ipmi_user =", colored(ipmi_user.strip(), 'blue'), \
            #     f"ipmi_pass =", colored(ipmi_pass.strip(), 'blue'), \
            # )

        maas_create_vm_machines(nodes)

except json.JSONDecodeError as e:
    print(f"JSON 데이터를 파싱할 수 없습니다: {e}")
