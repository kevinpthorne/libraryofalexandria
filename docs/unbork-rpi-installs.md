```bash
ip addr flush dev end0
ip link set lowtrust121 down
ip addr add 192.168.121.$NUM/24 dev end0
ip route add default via 192.168.121.1

rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```


Managed etcd cluster membership has been reset, restart without --cluster-reset flag now. Backup and delete ${datadir}/server/db on each peer etcd server and rejoin the nodes

