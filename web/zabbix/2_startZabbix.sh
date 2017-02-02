docker run \
--name zabbix \
-p 80:80 \
-p 10051:10051 \
-v /etc/localtime:/etc/localtime:ro \
--link zabbix-db:zabbix.db \
--env="ZS_DBHost=zabbix.db" \
--env="ZS_DBUser=zabbix" \
--env="ZS_DBPassword=ensyuu2" \
--env="XXL_zapix=true" \
--env="XXL_grapher=true" \
--net=shared_nw --ip=192.168.0.21 \
monitoringartist/zabbix-xxl:latest
