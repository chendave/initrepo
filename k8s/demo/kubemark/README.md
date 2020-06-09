everything needed to run kubemark locally,

firstly, kubemark image should be built, make sure the `kubemark` is existing,
and then copy the binary to `$KUBE_SRC/cluster/images/kubemark`

build the kubemark image with below command, 

```bash
cd $KUBE_SRC/cluster/images/kubemark
docker build -t kubemark:latest .
```

NOTE: both kubemaster and the external k8s cluster could be setup by kubeadm instead
of localup cluster shell script.

