#!/bin/bash

###################################################################
# This script is for Ceph deployment, using ``ceph-deploy`` tools.#
#								  #
#								  #
###################################################################
set -e

# remove the internal router
# sudo ip route delete default via 192.168.18.1 dev eno3  proto static  metric 100

# admin node
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
# add ceph packages to ubuntu repository
echo deb https://download.ceph.com/debian-luminous/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
# echo deb https://download.ceph.com/debian/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
# update your repository and install ceph-deploy
sudo apt-get update && sudo apt install ceph-deploy -y
# ssh-keygen on the admin node and then
# touch authorized_keys on each node and then
# copy the pub key to each of the node and then
# define /etc/hosts to include each node's info and then
# install "openssh-server" on each of node.
# install ntp and enable ntp service
sudo apt install ntp

# you cannot just modify /etc/sudoers, but instead do it as below:
echo "dave ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/dave

mkdir my-cluster
cd my-cluster
ceph-deploy new ceph2

# modify ceph.conf to add the public network configuration
# public network = 192.168.8.0/24

ceph-deploy install ceph2 ceph3 ceph4

# deploy the initial monitor(s) and gather the keys
ceph-deploy mon create-initial

# copy key and configuration file to each of nodes
ceph-deploy admin ceph2 ceph3 ceph4

# add three osd
ceph-deploy osd create ceph4:sdb

# deploy metadata server
ceph-deploy mds create ceph4

# need cleanup the partition on ceph3 first
ceph-deploy osd create ceph3:sdb
ceph-deploy osd create ceph3:sdc ceph3:sdd

# add one more node for monitor
ceph-deploy mon add ceph3 ceph4

# add rgw node for ceph cluster
ceph-deploy rgw create ceph3

# deploy ceph client node
ceph-deploy install ceph-client
ceph-deploy admin ceph-client

# ceph-client create block device image
rbd create foo --size 4096 --image-feature layering -m 192.168.17.21 -k /etc/ceph/ceph.client.admin.keyring
# map device
sudo rbd map foo --name client.admin -m 192.168.17.21 -k /etc/ceph/ceph.client.admin.keyring

# format the device and create file system
sudo mkfs.ext4 -m0 /dev/rbd0

# mount the filesytem on ceph client node
sudo mkdir /mnt/ceph-block-device
sudo mount /dev/rbd0 /mnt/ceph-block-device
cd /mnt/ceph-block-device
