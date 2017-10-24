#!/bin/sh

workdir=$(mktemp --directory)
trap "rm --force --recursive ${workdir}" SIGINT SIGTERM EXIT
echo "*********************************This is a Three Node CoreOS ETCD Cluster Configuration file generate Script******************************"
echo "Enter the Hostname for the Machine"
read kube1
echo "Enter the Core user Login password for the Machine"
read pass
openssl passwd -1 $pass >/tmp/config.txt
value="$(cat /tmp/config.txt)"
echo "The Core user Login password is $pass and this is Encrypt $value"
echo "Enter the IP address for the Machine"
read IP
echo "Enter the Gateway address for the Machine"
read GW
echo "Enter the DNS address for the Machine"
read DNS
echo "Hostname:$kube1"
echo "IP address:$IP"
echo "Gateway:$GW"
echo "DNS:$DNS"
echo "Enter the Hostname for Second Machine of the etcd cluter nodes"
read kube2
echo "Enter the IP address for Second Machine of the etcd cluter nodes"
read IP2
echo "Enter the Hostname for Third Machine of the etcd cluter nodes"
read kube3
echo "Enter the IP address for Third Machine of the etcd cluter nodes"
read IP3
echo "ETCD2 Cluster is $kube1=http://$IP,$kube2=http://$IP2,$kube3=http://$IP3" 
cat >${workdir}/cloud-config.yml <<EOF
#cloud-config
hostname: $kube1
coreos:
  etcd2:
    name: $kube1
    advertise-client-urls: http://$IP:2379
    initial-advertise-peer-urls: http://$IP:2380
    listen-client-urls: http://0.0.0.0:2379,http://0.0.0.0:4001
    listen-peer-urls: http://$IP:2380
    initial-cluster-token: etcd-kube-cluster
    initial-cluster: $kube1=http://$IP:2380,$kube2=http://$IP2:2380,$kube3=http://$IP3:2380
    initial-cluster-state: new
  units:
    - name: systemd-networkd.service
      command: stop
    - name: static.network
      runtime: true
      content: |
        [Match]
        Name=e*
        [Network]
        Address=$IP/24
        Gateway=$GW
        DNS=$DNS
    - name: down-interfaces.service
      command: start
      content: |
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/ip link set ens160 down
        ExecStart=/usr/bin/ip addr flush dev ens160
    - name: systemd-networkd.service
      command: restart
      enable: true
    - name: etcd2.service
      command: start
    - name: fleet.service
      command: start
    - name: systemd-networkd.service
      command: restart
    - name: docker.service
      command: start
users:
    - name: "core"
      passwd: $value 
      groups:
         - "sudo"
         - "docker"
EOF

rm -rf /tmp/config.txt 
cp ${workdir}/cloud-config.yml /usr/share/oem/cloud-config.yml
coreos-cloudinit -validate --from-file /usr/share/oem/cloud-config.yml
