#!/bin/bash

# NOTE: only for demo purpose, this scritps might has some assumption
# example:
# ./clean.sh binary
# ./clean.sh keadm
edge_node=`kubectl get node | grep -v master | sed -n '2 p' | awk '{print $1}'`
approach=$1

function cleanup_keadm() {
	# delete application
	kubectl delete -f $GOPATH/src/github.com/kubeedge/kubeedge/build/deployment.yaml
	# delete node
	kubectl delete node $edge_node
	# shutdown edgecore
	ssh root@$edge_node "keadm reset"
	ssh root@$edge_node "systemctl disable edgecore"
	ssh root@$edge_node "rm /etc/systemd/system/edgecore.service"
	# cleanup configuration
	ssh root@$edge_node "rm -rf /etc/kubeedge/*"
	ssh root@$edge_node "rm -rf /var/lib/kubeedge/*"
	# shutdown the cloudcore
	keadm reset
	# remove manifest on master
	rm -rf /etc/kubeedge/*

	cd $GOPATH/src/github.com/kubeedge/kubeedge/build/crds/devices
	kubectl delete -f devices_v1alpha2_devicemodel.yaml
	kubectl delete -f devices_v1alpha2_device.yaml
	cd $GOPATH/src/github.com/kubeedge/kubeedge/build/crds/reliablesyncs
	kubectl delete -f cluster_objectsync_v1alpha1.yaml
	kubectl delete -f objectsync_v1alpha1.yaml
}


function cleanup_binary() {
	# delete application
	kubectl delete -f $GOPATH/src/github.com/kubeedge/kubeedge/build/deployment.yaml
	# delete node
	kubectl delete node $edge_node
	# shutdown edgecore
	ssh root@$edge_node "bash /root/devsummit/cleanup.sh"
	ssh root@$edge_node "rm /root/kubeedge/edgecore.log"
	# cleanup configuration
	ssh root@$edge_node "rm -rf /etc/kubeedge/*"
	ssh root@$edge_node "rm -rf /var/lib/kubeedge/*"
	# remove manifest on master
	rm -rf /etc/kubeedge/*

	# stop cloudcore
	pid=`ps -ef | grep cloudcore | grep -v grep | awk -F " " '{print $2}'`
	kill -9 $pid
	rm /root/kubeedge/cloudcore.log

	cd $GOPATH/src/github.com/kubeedge/kubeedge/build/crds/devices
        kubectl delete -f devices_v1alpha2_devicemodel.yaml
        kubectl delete -f devices_v1alpha2_device.yaml
        cd $GOPATH/src/github.com/kubeedge/kubeedge/build/crds/reliablesyncs
        kubectl delete -f cluster_objectsync_v1alpha1.yaml
        kubectl delete -f objectsync_v1alpha1.yaml

}

case $1 in
        binary)
                cleanup_binary
                ;;
        keadm)
                cleanup_keadm
                ;;
esac

sleep 10
ssh root@$edge_node "systemctl restart docker"
