使い方
=====

必要なもの
--------
- Controller用PC(Cont)
-- VM Ubuntu, trema実行環境，2 ethernet card(192.168.1.4(Controller), 192.168.0.10)
- Server用PC(Serv)
-- Native Ubuntu(192.168.0.254), docker, docker images(zabbix, php:5.6-apache)
- UserPC(User)
-- Any OS(192.168.0.x, 30<x<100)

起動手順
-------
1. trema実行(Cont)
```
$ ./bin/trema run ./lib/routing_switch.rb -- --slicing
```

2. ネットワークブリッジセットアップ(Serv)
```
$ ./docker/network_setup.sh
```

3. コンテナ作成用node.js起動(Serv)
```
$ node ./web/index.js
```

4. zabbix起動(Serv)
それぞれ別のターミナルで，
```
$ ./web/zabbix/1_startDB.sh
```
```
$ ./web/zabbix/2_startZabbix.sh
```
```
$ ./web/zabbix/3_startMonitoring.sh
```
お好みで起動したzabbix上(web)で./web/zabbix内のxmlを適用してください

5. ブラウザ上からServにアクセス(User)
ブラウザから，
```
192.168.0.254:8124
```
へアクセス
表示されたipアドレスにアクセス可能となる．
