# 10.169.41.183 is the ip address of kubemaster (not the external cluster)
# run this on the external cluster master node to setup the kubemark
export RESOURCE_DIRECTORY=/home/dave/kubemark
export LOCAL_KUBECONFIG=admin.kubeconfig
scp root@10.169.41.183://root/.kube/config /home/dave/kubemark/admin.kubeconfig
kubectl create -f kubemark-ns.json
kubectl create configmap "node-configmap" --namespace="kubemark" --from-literal=content.type="" --from-file=kernel.monitor="${RESOURCE_DIRECTORY}/kernel-monitor.json"
kubectl create secret generic "kubeconfig" --type=Opaque --namespace="kubemark" \
--from-file=kubelet.kubeconfig="${LOCAL_KUBECONFIG}" \
--from-file=kubeproxy.kubeconfig="${LOCAL_KUBECONFIG}" \
--from-file=npd.kubeconfig="${LOCAL_KUBECONFIG}" \
--from-file=heapster.kubeconfig="${LOCAL_KUBECONFIG}" \
--from-file=cluster_autoscaler.kubeconfig="${LOCAL_KUBECONFIG}" \
--from-file=dns.kubeconfig="${LOCAL_KUBECONFIG}"
kubectl create -f "${RESOURCE_DIRECTORY}/hollow-node.yaml" --namespace="kubemark"
