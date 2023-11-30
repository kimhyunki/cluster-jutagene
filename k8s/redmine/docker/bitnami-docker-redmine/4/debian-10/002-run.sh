#!/bin/bash

docker rm falinux-redmine

docker run -d --name falinux-redmine \
	-p 8081:3000 \
	--env ALLOW_EMPTY_PASSWORD=yes \
    --env MARIADB_ROOT_USER="admin" \
    --env MARIADB_ROOT_PASSWORD="admin" \
    --env MYSQL_CLIENT_CREATE_DATABASE_NAME="falinux-redmine" \
    --env MYSQL_CLIENT_CREATE_DATABASE_PASSWORD="falinux-redmine" \
	falinux-redmine:latest

docker logs falinux-redmine -f
