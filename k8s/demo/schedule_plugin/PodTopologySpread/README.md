Here is the way to make the pod pending on scheduling due to the `PodTopologySpread`:

I have two nodes:
entos-xeon: slave
dave-desktop: master

step1: Define the node label (topologyKey) on two nodes,
kubectl label node dave-desktop kubernetes.io/region=usa
kubectl label node dave-desktop kubernetes.io/unexist=usa
kubectl label node entos-xeon kubernetes.io/region=china
kubectl label node entos-xeon kubernetes.io/unexist=china


step2:
```
- kubectl create -f httpd.yaml  //suppose the pods will spread to the nodes as this (entos-xeon:2, dave-desktop:1) - corresponding to the constraints (matchLabels and matchExpressions: name).
```

step3:
```
- kubectl create -f pod.yaml    //the pod will enforce the pod being scheduled to a specific node (dave-desktop:2) - corresponding to the constraints (matchExpressions: name)
```

The overall topology now is:
topologyKey: kubernetes.io/region -
constraints1(matchLabels): entos-xeon:2, dave-desktop:1 (dave-desktop is selected for the new pod)
topologyKey: kubernetes.io/unexist -
constraints2(matchExpressions): entos-xeon:2, dave-desktop:3 (entos-xeon is selected for the new pod)

If we create another pod with `PodTopologySpread`

```
kubectl create -f topology.yaml
```

The pod won't got scheduled and is always pending.
