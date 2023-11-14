#!/usr/bin/env python3
import sys
import json
import argparse
import subprocess

ips = []
file = open(sys.argv[1], "r")
try:
    data = json.load(file)
except ValueError as e:
    print("Error: %s" % e)
    sys.exit(1)
for cluster in data["clusters"]:
    for node in cluster["nodes"]:
        ips.append(node["node"]["hostnames"]["storage"][0])

#print(ips) 


for ip in ips:
    cmd = "ssh ubuntu@%s ls" % ip
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    print(out.decode("utf-8"))

exit

#for ip in ips:
#    cmd = "ssh %s 'hostname'" % ip
#    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
#    out, err = p.communicate()
#    print(out.decode("utf-8"))

#cmd = ssh ubuntu@ips
#
## ips by ssh command 
## Path: topology-ssh.py
##!/usr/bin/env python3
#import sys
#import subprocess
#import json
#import argparse
#
#ips = []
#file = open(sys.argv[1], "r")
#try:
#    data = json.load(file)
#except ValueError as e:
#    print("Error: %s" % e)
#    sys.exit(1)
#for cluster in data["clusters"]:
#    for node in cluster["nodes"]:
#        ips.append(node["node"]["hostnames"]["storage"][0])
#
#
#
#