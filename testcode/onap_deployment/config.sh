#!/bin/bash
source ~/env/v3rc
# NOTE: You must do those under the demo project, and you should make sure your instance is created under demo project
# Before running the following steps, make sure your first HDD has enough space and the volume group created by openstack
# is larger than 200G, or else try below:
# 1. pvcreate /dev/sdc
# 2. vgextend ubuntu-vg /dev/sdc
# 3. lvextend -L +1000G /dev/mapper/ubuntu--vg-root
# 4. do the same thing (step1, step2) to extend stack-volumes-lvmdriver-1 (cinder default volume group).

export OS_PROJECT_NAME=demo
pushd /home/dave/onap/resource
openstack keypair create --public-key onap_rsa.pub onap
openstack quota set demo --instances 20
openstack quota set demo --cores 40
openstack quota set demo --ram 71680
openstack flavor delete m1.xlarge
openstack flavor create m1.xlarge --ram 6144 --vcpus 4 --disk 100
openstack flavor delete m1.large
openstack flavor create m1.large --ram 6144 --vcpus 3 --disk 80

# NOTE: You need download those cloud image and drop them under the current dir
openstack image create ubuntu1604 --file ubuntu-14.04-server-cloudimg-amd64-disk1.img --disk-format qcow2
openstack image create ubuntu1404 --file ubuntu-14.04-server-cloudimg-amd64-disk1.img --disk-format qcow2

pubnet_id=`openstack network list -f value | grep "public" | awk -F' ' {'print $1'}`
sed -i "s/.*public_net_id.*/  public_net_id: $pubnet_id/g" onap_openstack.env

project_id=`openstack project list -f value | grep "demo" | head -1 | awk -F' ' {'print $1'}`
sed -i "s/.*openstack_tenant_id.*/  openstack_tenant_id: $project_id/g" onap_openstack.env

# TODO, need replace the local server IP

openstack stack create -t onap_openstack.yaml -e onap_openstack.env ONAP
popd

# openstack stack delete ONAP
