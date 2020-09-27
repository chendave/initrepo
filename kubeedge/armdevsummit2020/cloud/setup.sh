#!/bin/bash

# NOTE: only for demo purpose, this scritps has some assumption, for example, binary of keadm should be built early.
# node port of the deployment has been updated from "80" to "8899" to avoid the conflict.
# logs on the cloud side
# /var/log/kubeedge/cloudcore.log
# logs on edge side
# journalctl -u edgecore.service -b

# first parameter is the ip of the edge
# second parameter is the ip of cloud to use for advertise
# third parameter is the way to setup the kubeedge, either binary or keadm
# example:
# ./setup.sh 10.169.214.119 10.169.212.218 keadm
# ./setup.sh 10.169.214.119 10.169.212.218 binary
# diff /tmp/edgecore.yaml /etc/kubeedge/config/edgecore.yaml to see the change.
# MqttMode has been updated from 2 o 1 (enable internal as well as external broker).

edge_node_ip=$1
advertise_address=$2
approach=$3

# binary
function binary_cloud() {
	cd /root/kubeedge
	mkdir /etc/kubeedge/config
	# create configuration file
	./cloudcore --defaultconfig > /etc/kubeedge/config/cloudcore.yaml
	cd $GOPATH/src/github.com/kubeedge/kubeedge/build/crds/devices
	kubectl create -f devices_v1alpha2_devicemodel.yaml
	kubectl create -f devices_v1alpha2_device.yaml
	cd $GOPATH/src/github.com/kubeedge/kubeedge/build/crds/reliablesyncs
	kubectl create -f cluster_objectsync_v1alpha1.yaml
	kubectl create -f objectsync_v1alpha1.yaml
	cd ~/kubeedge
	nohup ./cloudcore > cloudcore.log 2>&1 &
}

# binary
function binary_edge() {
	ssh root@"$edge_node_ip" "bash /root/devsummit/setup.sh"
	token=`kubectl get secret -nkubeedge tokensecret -o=jsonpath='{.data.tokendata}' | base64 -d`
	echo $token

	ssh root@"$edge_node_ip" "cd /etc/kubeedge/config; sed -i -e 's|token: .*|token: ${token}|g' edgecore.yaml"
	ssh root@"$edge_node_ip" "cd /root/kubeedge/; nohup ./edgecore > edgecore.log 2>&1 &"
}

# setup the master
function keadm_cloud() {
	keadm init --advertise-address="$advertise_address"
}

# setup edge
function keadm_edge() {
	token=$(keadm gettoken)
	echo $token
	sleep 5
	ssh root@"$edge_node_ip" "keadm join --cloudcore-ipport=$advertise_address:10000 --token=$token"
}


function pre_check() {
	kubectl apply -f $GOPATH/src/github.com/kubeedge/kubeedge/build/deployment.yaml
	sleep 20
	curl $edge_node_ip:8899
}

#setup by keadm
function setup_keadm() {
	keadm_cloud
	sleep 5
	keadm_edge
}


#setup by binary
function setup_binary() {
	binary_cloud
	sleep 10
	binary_edge
}

# run pre_check later until the node is ready
#pre_check
case $3 in 
	binary)
		setup_binary
		;;
	keadm)
		setup_keadm
		;;
esac
