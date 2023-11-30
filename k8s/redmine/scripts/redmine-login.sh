#!/bin/sh

redmine_pod=`kubectl -n redmine get po | grep -v mariadb | awk '/^redmine-/{ print $1 }'`

kubectl -n redmine exec -ti $redmine_pod bash

