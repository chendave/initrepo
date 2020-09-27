Here are some sample scripts used for demo purpose, you must need at least two nodes to
try those scripts for the installation of KubeEdge.

This guide assume you have `Docker` pre-installed on both cloud and edge node, `kubelet` `kubeadm` `kubectl` pre-installed on cloud,
or else, pls refer to [here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

- Configure no password ssh connection from cloud to edge,
  ```bash
  ssh-keygen
  ```
  Copy the `id_rsa.pub` to `authorized_keys` on the edge.


- Create K8S cluster based on `kubeadm`,
  ```bash
  kubeadm init --pod-network-cidr=192.168.0.0/16
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
  ```

- Copy the folder of "cloud" to somewhere on the cloud node

- Copy the folder of "edge" to "/root/devsummit" on the edge node

- Installation based on `keadm`
  ```bash
  cd cloud
  setup.sh $edge_node_ip $cloud_node_ip keadm
  ```

- Installation based on `binary`
  ```bash
  cd cloud
  setup.sh $edge_node_ip $cloud_node_ip binary
  ```

- clean up all the stuff created by `keadm`
  ```bash
  cd cloud
  clean.sh keadm
  ```

- clean up all the stuff created by `binary`
  ```bash
  cd cloud
  clean.sh binary
  ```

- Create a sample application, 
  ```bash
  kubectl apply -f $GOPATH/src/github.com/kubeedge/kubeedge/build/deployment.yaml
  sleep 20
  curl $edge_node_ip:8899
  ```

NOTE: 
1. node port of the deployment has been updated from "80" to "8899" to avoid the conflict, pls refer to "deployment.yaml.patch".
2. For the case of binary installation, default `edgecore.yaml` should be updated, pls refer to "edgecore.yaml.patch`. 
