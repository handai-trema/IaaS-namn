docker run \
    --name zabbix-db \
    --env="MARIADB_USER=zabbix" \
    --env="MARIADB_PASS=ensyuu2" \
--net=shared_nw --ip=192.168.0.20 \
    monitoringartist/zabbix-db-mariadb
