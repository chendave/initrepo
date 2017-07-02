#!/bin/bash

#This sample doesn't work, it might be the init script is not written correctly.
#will dig into the issue in the future.

sed -e

cd /tmp
wget http://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img

openstack image create --name IPtables --container-format bare --disk-format qcow2 --public True --file ubuntu-14.04-server-cloudimg-amd64-disk1.img

# create a user data file
cat << EOF > ./user-data.txt
#cloud-config
password: abc123
chpasswd: { expire: False }
ssh_pwauth: True
EOF


# create an instance
nova boot --flavor m1.medium --user-data=./user-data.txt --image IPtables IPtable-temp --nic net-id=079ecf62-f875-4606-a890-5036c63eb0da


# TODO
# login the VM and change root password
# cannot login the VM with the password "abc123"

# reference:
# [1] https://www.juniper.net/documentation/en_US/nfv2.1/topics/task/installation/ccpe-lxciptable-vnf-image-creating.html
