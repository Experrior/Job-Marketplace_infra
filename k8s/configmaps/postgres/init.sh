#!/bin/sh
echo test;
until pg_basebackup --pgdata=/var/lib/postgresql/data -R --dbname='postgresql://admin:test@$PRIMARY_HOST_NAME/JobMarketDB' --slot=replication_slot --host=$PRIMARY_HOST_NAME --port=5432;
do
echo 'Waiting for primary to connect...';
sleep 5s;
done
echo 'Backup done, starting replica...';
chmod 0700 /var/lib/postgresql/data;
docker-entrypoint.sh -c config_file=/etc/postgresql.conf -c hba_file=/etc/pg_hba.conf;