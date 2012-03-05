#!/bin/bash

## ASSUMES RHUI DVD in /root ###
## Run on the rhua and each cds ##
##
## example ./script.sh rhua xvdk
## example ./script.sh cds xvdf (xvdf for 6.0 rhel or so I've seen)
# Update if working in beaker.. you probably cant add a large mount
# set export env

## CHANGE ME ####
export rhua=host.internal	
export cds1=host.internal
export cds2=host.internal
export ec2pem=/root/wes-us-west-2.pem
## CHANGE ME ####

export rhui_ip='dig +short' 
export cds1_ip='dig +short'
export cds2_ip='dig +short'

echo "$rhui_ip $rhua" >> /etc/hosts
echo "$cds1_ip $cds1" >> /etc/hosts
echo "$cds2_ip $cds2" >> /etc/hosts


#options rhua or cds
export server="$1"
#options /dev/$someDevice
export device="$2"
 

if [ "$server" == "rhua" ]; then
 echo "RHUI Selected"
 mkdir /var/lib/pulp
 ls /var/lib/pulp
fi
if [ "$server" == "cds" ]; then
 echo "CDS Selected"
 mkdir /var/lib/pulp-cds
 ls /var/lib/pulp-cds
fi

iptables --flush

iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A INPUT -p icmp -j ACCEPT 
iptables -A INPUT -i lo -j ACCEPT 
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW  -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW  -m tcp --dport 5674 -j ACCEPT

/etc/init.d/iptables save
/etc/init.d/iptables restart

fdisk /dev/$device << EOF
n
p
1
1
54823
p
w
EOF

export partition=1
mkfs.ext4 /dev/$device$partition

if [ "$server" == "rhua" ]; then
 echo "/dev/$device$partition /var/lib/pulp ext4 defaults 1 1" >> /etc/fstab
 mount -a 
 mount 
fi
if [ "$server" == "cds" ]; then
 echo "/dev/$device$partition /var/lib/pulp-cds ext4 defaults 1 1" >> /etc/fstab
 mount -a
 mount
fi

if [ "$server" == "rhua" ]; then
 mkdir -p pem && pushd pem
 openssl req -new -x509 -extensions v3_ca -keyout ca.key -subj '/C=US/ST=NC/L=Raleigh/CN=localhost' -out ca.crt -days 365
 echo 10 > ca.srl
 openssl genrsa -out server.key 2048

 for node in $rhua $cds1 $cds2 ; do 
  echo -ne "\n\n\n## set CN for $server\n=="
  openssl req -new -key server.key -subj '/C=US/ST=NC/L=Raleigh/CN='$node'' -out $node.csr
  openssl x509 -req -days 365 -CA ca.crt -CAkey ca.key -in $node.csr -out $node.crt
 done
fi

mkdir /tmp/mnt
mount -o loop /root/RH* /tmp/mnt/
pushd /tmp/mnt/
if [ "$server" == "rhua" ]; then
 yum -y install rpm-build
 ./install_RHUA.sh ;./install_tools.sh 
fi
if [ "$server" == "cds" ]; then
 ./install_CDS.sh
fi

popd

if [ "$server" == "rhua" ]; then
 nss-db-gen
fi

if [ "$server" == "rhua" ]; then
 if [ -e "/etc/pulp/pulp.conf" ]; then
  sed -i 's/server_name: localhost/server_name: $rhui/g' /etc/pulp/pulp.conf;
  cat /etc/pulp/pulp.conf | grep server_name 
 fi
 if [ -e "/etc/pulp/client.conf" ]; then
  sed -i 's/host = localhost.localdomain/host = $rhui/g' /etc/pulp/client.conf;
  cat /etc/pulp/client.conf | grep host
 fi
 if [ -e "/etc/pulp/consumer/consumer.conf" ]; then
  sed -i 's/host = localhost.localdomain/host = $rhui/g' /etc/pulp/consumer/consumer.conf;
  cat /etc/pulp/consumer/consumer.conf | grep host
 fi
 if [ -e "/etc/rhui/rhui-tools.conf" ]; then
  sed -i 's/hostname: localhost/hostname: $rhui/g' /etc/rhui/rhui-tools.conf;
  cat /etc/rhui/rhui-tools.conf | grep hostname
 fi
fi

if [ "$server" == "cds" ]; then
 sed -i 's/host = localhost.localdomain/host = $rhui/g' /etc/pulp/cds.conf;
 cat /etc/pulp/cds.conf | grep host
fi

export cert=.crt

cat > /root/answers.txt <<DELIM
[general]
version: 1.0
dest_dir: /tmp/rhui
qpid_ca: /tmp/rhua/qpid/ca.crt
qpid_client: /tmp/rhua/qpid/client.crt
qpid_nss_db: /tmp/rhua/qpid/nss
[rhua]
rpm_name: rh-rhua-config
hostname: $rhua
ssl_cert: /root/pem/$rhua$cert
ssl_key: /root/pem/server.key
ca_cert: /root/pem/ca.crt
# proxy_server_host: proxy.example.com
# proxy_server_port: 443
# proxy_server_username: admin
# proxy_server_password: password
[cds-1]
rpm_name: rh-cds1-config
hostname: $cds1
ssl_cert: /root/pem/$cds1$cert
ssl_key: /root/pem/server.key
[cds-2]
rpm_name: rh-cds2-config
hostname: $cds2
ssl_cert: /root/pem/$cds2$cert
ssl_key: /root/pem/server.key

DELIM

if [ "$server" == "rhua" ]; then
 /usr/bin/rhui-installer /root/answers.txt

 scp -i $ec2pem /root/RH* root@$cds1:/root
 scp -i $ec2pem /root/installRHUI.sh root@$cds1:/root
 scp -i $ec2pem -r /tmp/rhui root@$cds1:/tmp
 scp -i $ec2pem /etc/hosts root@cds1:/etc/hosts

 scp -i $ec2pem /root/RH* root@$cds2:/root
 scp -i $ec2pem /root/installRHUI.sh root@$cds2:/root
 scp -i $ec2pem -r /tmp/rhui root@$cds2:/tmp
 scp -i $ec2pem /etc/hosts root@cds2:/etc/hosts
fi
