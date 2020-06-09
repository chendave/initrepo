# 10.169.41.183 is the ip address of kubemaster (not the external cluster)
# 10.169.36.51 is the ip address of master of  external cluster 
# ssh-copy-id -i ~/.ssh/id_rsa root@10.169.36.51
export KUBE_SSH_USER=root
export KUBEMARK_SSH_KEY="/root/.ssh/id_rsa"
#go run cmd/clusterloader.go --kubeconfig=/var/run/kubernetes/admin.kubeconfig --testconfig=testing/load/config.yaml --kubemark-root-kubeconfig /var/run/kubernetes/admin.kubeconfig --masterip=10.169.36.51 --provider=kubemark --nodes=100 --report-dir=/var/log/kubernetes/e2e/load/kubeadm
#go run cmd/clusterloader.go --kubeconfig=/root/.kube/config --testconfig=testing/load/config.yaml --kubemark-root-kubeconfig /root/.kube/config --masterip=10.169.36.51 --provider=kubemark --nodes=100 --report-dir=/var/log/kubernetes/e2e/load/kubeadm_fixed

#go run cmd/clusterloader.go --kubeconfig=/root/.kube/config --testconfig=testing/load/config.yaml --kubemark-root-kubeconfig /root/.kube/config --provider=kubemark --nodes=100 --masterip=10.169.41.183 --report-dir=/var/log/perf/load --log_dir=/var/log/perf/log --etcd-insecure-port=2381

#go run cmd/clusterloader.go --kubeconfig=/root/.kube/config --testconfig=testing/density/config.yaml --testconfig=testing/load/config.yaml  --provider=kubemark --nodes=100 --masterip=10.169.41.183 --report-dir=/var/log/perf/result_arm --log_dir=/var/log/perf/log --etcd-insecure-port=2381

# on old release breanch
#go run cmd/clusterloader.go --kubeconfig=/root/.kube/config --testconfig=testing/node-throughput/config.yaml --testoverrides=testing/node-throughput/docker_override.yaml --provider=kubemark --nodes=100 --masterip=10.169.41.183 --report-dir=/var/log/test/throughput2 --log_dir=/var/log/test/throughput2/log --etcd-insecure-port=2381

# on latest master 
go run cmd/clusterloader.go --kubeconfig=/root/.kube/config --testconfig=testing/node-throughput/config.yaml --provider=kubemark --nodes=100 --masterip=10.169.41.183 --report-dir=/var/log/test/throughput2 --log_dir=/var/log/test/throughput2/log --etcd-insecure-port=2381
