label one of the node in the cluster
```bash
kubectl label node entos-xeon kubernetes.io/region=china
```

then create pod with below config respectively,
```bash
kubectl create -f pod-with-pod1-affinity.yaml  // score got will be 100
pod-with-pod2-affinity.yaml // score got will be 300 (pod1 - 100, pod12- 100, pod2/pod1 - 100)
pod-with-pod3-affinity.yaml // pod won't be schedulered, condition cannbe matched.
```
