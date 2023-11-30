#!/usr/bin/env bash

docker cp 2023-09-01-postgresql-backup.tar docker_falinux-service-redmine-local_1:/mnt/2023-09-01-postgresql-backup.tar

echo "input falinux password : 2---M---"

docker exec -ti docker_falinux-service-redmine-local_1 bash -c "pg_restore -U falinux -h postgresql -d falinux-redmine -c /mnt/2023-09-01-postgresql-backup.tar"
docker exec -ti docker_falinux-service-redmine-local_1 bash -c "pg_restore -U falinux -h postgresql -d falinux-redmine -c /mnt/2023-09-01-postgresql-backup.tar"
