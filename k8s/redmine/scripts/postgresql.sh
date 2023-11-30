#!/bin/sh

while [ 1 ]
do
kubectl -n redmine logs postgresql -f
sleep 1
clear
done
