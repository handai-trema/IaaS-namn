docker network rm shared_nw
docker network create -d bridge --subnet 192.168.0.0/24 --opt "com.docker.network.bridge.name"="br0" shared_nw
sudo ifconfig eth0 0.0.0.0 promisc up
sudo brctl addif br0 eth0
sudo ifconfig br0 192.168.0.254 up
