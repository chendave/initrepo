Example on the service affinity
===============================

1. Set label for one node in your cluster
```bash
kubectl label nodes slave bar="dave"
```

2. Start scheduler service with the config file
```bash
go run ./scheduler.go --config=/etc/kubernetes/config/kube-scheduler.yaml
```

3. Create a pod with label `bar` defined, 
```bash
kubectl create -f initial.yaml
```

4. Create a service which will map to the pod, this pod will scheduled on the `slave` node
```bash
kubectl create -f service.yaml
```

5. Create another pod, this pod will be scheduled to the same node.
```bash
kubectl create -f affinity.yaml
```
