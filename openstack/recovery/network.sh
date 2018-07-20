#!/bin/bash

# set -e -x
set -e

#### source env
# type the alias "stack" and then source env.
# stack
cd /home/dave/Project/OpenStack/devstack
source openrc admin admin



#### address the security group
proj_id=`openstack project list | grep demo | grep -v alt | awk -F "|" '{print $2}' | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
secgrp_id=`openstack security group list | grep $proj_id | awk -F "|" '{print $2}' | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
openstack security group rule create $secgrp_id --ingress --protocol icmp --description "for ping"
openstack security group rule create $secgrp_id --ingress --protocol tcp --dst-port 22

#### address DNS
# ssh cirros@$floating_ip

