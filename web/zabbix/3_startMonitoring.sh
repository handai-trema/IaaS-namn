docker run \
--name=zabbix-agent-xxl \
-h 'docker-host-1' \
-p 10050:10050 \
-v /:/rootfs \
-v /var/run:/var/run \
-e "ZA_Server=<192.168.0.21/24>" \
--net=shared_nw --ip=192.168.0.22 \
monitoringartist/zabbix-agent-xxl-limited:latest
