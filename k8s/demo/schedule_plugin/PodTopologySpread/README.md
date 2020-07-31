Here is the way to make the preemptor pod pending or preempt the low priority pods on nodes when scheduling due to the `PodTopologySpread`:

scenario:
I have two nodes:
- node2: slave
- node1: master

step1: Define the node label (topologyKey) on two nodes (taint is removed on master node):
```bash
kubectl label node node1 kubernetes.io/region1=usa
kubectl label node node1 kubernetes.io/region2=usa
kubectl label node node2 kubernetes.io/region1=china
kubectl label node node2 kubernetes.io/region2=china
```


step2:
```bash
- kubectl create -f httpd.yaml
```

Suppose the spreading looks like this:
node2:2, node1:1
This is corresponding to the constraints of (matchLabels and matchExpressions: name).

step3:
```bash
- kubectl create -f pod1.yaml
- kubectl create -f pod2.yaml
```
Enforce the pod to be scheduled to a specific node (node1:2), create two pods here, this is corresponding to the constraints (matchExpressions: name)

Until we see something like this, 
```
NAME                     READY   STATUS    RESTARTS   AGE     IP          NODE           NOMINATED NODE   READINESS GATES
exist1                   1/1     Running   0          22d     10.32.0.4   node1          <none>           <none>
exist2                   1/1     Running   0          7d21h   10.32.0.6   node2          <none>           <none>
```


The overall topology now is:
topologyKey: kubernetes.io/region1 -
constraints1(matchLabels): node2:2, node1:1 (node1 is selected for the preemptor pod)
topologyKey: kubernetes.io/region2 -
constraints2(matchExpressions): node2:2, node1:3 (node2 is selected for the preemptor pod)

Final layout is:
```
NAME                     READY   STATUS    RESTARTS   AGE     IP          NODE           NOMINATED NODE   READINESS GATES
exist1                   1/1     Running   0          22d     10.32.0.4   node1          <none>           <none>
exist2                   1/1     Running   0          7d21h   10.32.0.6   node1          <none>           <none>
httpd-6cb7f4995d-5zdtx   1/1     Running   0          23h     10.32.0.5   node1          <none>           <none>
httpd-6cb7f4995d-b8ccf   1/1     Running   0          23h     10.44.0.2   node2          <none>           <none>
httpd-6cb7f4995d-p6pbk   1/1     Running   0          12h     10.44.0.3   node2          <none>           <none>
```


If we create another pod with `PodTopologySpread`

```
kubectl create -f preemptor.yaml
```

The preemptor pod will preempt the lower priority pod on other node1/node2, while change it's priority from `system-cluster-critical` to default priority will make it always pending.
