kube-state-metrics
==================


github: https://github.com/kubernetes/kube-state-metrics

the metrics are all about the k8s objects, such as deployments, nodes and ports.

- value is stored in memory
- stores the latest values only

deploy
=====
kubectl apply -f  examples/standard

access
======
# kubectl run --rm utils -it --image arunvelsriram/utils -n kube-system bash
utils@utils:~$ curl kube-state-metrics:8080

Note: the service is a headless service, and the service is exposed in the namespace of `kube-system`, so you cannot access the service via the host IP directly.

Instead, you can switch to use `nodePort` and access the service with the host IP.
