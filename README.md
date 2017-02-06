使い方
=====

必要なもの
--------
- Controller用PC(Cont)
-- VM Ubuntu, trema実行環境，2 ethernet card(192.168.1.4(Controller), 192.168.0.10)
- Server用PC(Serv)
-- Native Ubuntu(192.168.0.254)
-- need to install
--- docker
--- docker images(zabbix, php:5.6-apache)
--- node.js environment
- UserPC(User)
-- Any OS(192.168.0.x, 30<x<100)

起動手順
-------
* 1. trema実行(Cont)
```
$ ./bin/trema run ./lib/routing_switch.rb -- --slicing
```

* 2. ネットワークブリッジセットアップ(Serv)
```
$ ./docker/network_setup.sh
```

* 3. コンテナ作成用node.js起動(Serv)
```
$ node ./web/index.js
```

* 4. zabbix起動(Serv)

それぞれ別のターミナルで，以下のスクリプトを順に実行．
ただし，それぞれの起動には時間がかかるため，前のものが起動できたことを確認してからスクリプトを実行すること．
```
$ ./web/zabbix/1_startDB.sh
```
```
$ ./web/zabbix/2_startZabbix.sh
```
```
$ ./web/zabbix/3_startMonitoring.sh
```
お好みで起動したブラウザで，zabbixにログイン（デフォルトでIDはadmin，passはzabbix）した後，設定タブのテンプレートのインポートで./web/zabbix内のxmlをインポート．その後は設定タブのホスト作成でdockerコンテナ監視用のホストを作り，先ほどインストールしたテンプレートを適用．しばらくするとdockerコンテナの監視が開始される．

* 5. ブラウザ上からServにアクセス(User)

ブラウザから，
```
192.168.0.254:8124
```
へアクセス．  
作成されたコンテナのipアドレスが返ってくるので，
ブラウザ上からアクセス可能となっている．

* 6. コンテナへアクセス（User）

Servへのアクセスにより返ってきたipアドレスをブラウザに入力するとコンテナ上のwebサーバにアクセスして，サービスが享受できるようになっている．
