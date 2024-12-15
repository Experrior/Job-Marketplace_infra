#!/bin/bash
pwd
sleep 10s
until pg_basebackup --pgdata=/var/lib/postgresql/data -R --slot=replication_slot --host="${PRIMARY_HOST_NAME}"; do
  echo 'Waiting for primary to connect...'
  sleep 5s
done
echo 'Backup done, starting replica...'
chmod 0700 /var/lib/postgresql/data
docker-entrypoint.sh -c config_file=/etc/postgresql/postgresql.conf
