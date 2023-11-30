#!/bin/sh

namespace=redmine
service=postgresql

#pod_name=`kubectl -n $namespace get po | grep -v postgresql | grep -v redis | awk '/^gitlab/{ print $1 }'`
while [ 1 ]
do
pod_name=`kubectl -n $namespace get po | awk '/^'$service'/{ print $1 }'`


if [ -n $redmind_pod ]; then
	kubectl -n $namespace logs $pod_name -f
fi

sleep 1

clear
done


