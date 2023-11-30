#!/bin/sh

while [ 1 ]
do
redmine_pod=`kubectl -n redmine get po | grep -v mariadb | grep -v postgresql | awk '/^redmine-/{ print $1 }'`

if [ -n $redmind_pod ]; then
	kubectl -n redmine logs $redmine_pod -f 
fi

sleep 1

clear
done

#kubectl -n redmine logs falinux-redmine-mariadb-0 -f
