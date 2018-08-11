#!/bin/bash

# set -e -x
set -e

#### source env
# type the alias "stack" and then source env.
# stack
cd /home/dave/Project/OpenStack/devstack
source openrc admin demo


#### Discovery any of compute node
cd tools
bash discover_hosts.sh


#### address the security group
proj_id=`openstack project list | grep demo | grep -v alt | awk -F "|" '{print $2}' | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
secgrp_id=`openstack security group list | grep $proj_id | awk -F "|" '{print $2}' | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
openstack security group rule create $secgrp_id --ingress --protocol icmp --description "for ping"
openstack security group rule create $secgrp_id --ingress --protocol tcp --dst-port 22

#### address DNS
# ssh cirros@$floating_ip


#### create another private network and attach the interface into router
openstack network create private2 --project demo
openstack subnet create private2-subnet --project demo --subnet-range 10.0.8.0/26 --network private2
subnet_id=`openstack subnet list | grep private2-subnet | awk -F "|" '{print $2}' | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
neutron router-interface-add router1 subnet=$subnet_id

### Create the keypair that canbe used for access the VM
openstack keypair create test --public-key ~/.ssh/id_rsa.pub

### create an instance with the new network, update the server name accordingly.
openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.tiny --key-name local --availability-zone nova:os-compute1 --nic net-id=private2 test1


### ping the instance, example
#  $ sudo ip netns exec qrouter-3b1a4673-4ada-4988-a11b-86fcacfb0ea0 ping -c 2 10.0.8.10
#  PING 10.0.8.10 (10.0.8.10) 56(84) bytes of data.
#  64 bytes from 10.0.8.10: icmp_seq=1 ttl=64 time=1.62 ms
#  64 bytes from 10.0.8.10: icmp_seq=2 ttl=64 time=0.838 ms
#  
#  --- 10.0.8.10 ping statistics ---
#  2 packets transmitted, 2 received, 0% packet loss, time 1001ms
#  rtt min/avg/max/mdev = 0.838/1.230/1.622/0.392 ms

