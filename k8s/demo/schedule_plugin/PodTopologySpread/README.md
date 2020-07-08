Here is the way to make the pod pending on scheduling due to the `PodTopologySpread`:

I have two nodes:
entos-xeon: slave
dave-desktop: master

step1:
```
- kubectl create -f httpd.yaml  //suppose the pods will spread to the nodes as this (entos-xeon:3, dave-desktop:1) - corresponding to the constraints (matchLabels and matchExpressions: name), so you need to run this command four times.
```

step2:
```
- kubectl create -f pod.yaml    //the pod will enforce the pod being scheduled to a specific node (entos-xeon: 1, dave-desktop:4) - corresponding to the constraints (matchExpressions: name)
```

The overall topology now is:
constraints1(matchLabels): entos-xeon:3, dave-desktop:1 (dave-desktop is selected for the new pod)
constraints2(matchExpressions): entos-xeon:4, dave-desktop:5 (entos-xeon is selected for the new pod)

If we create another pod with `PodTopologySpread`

```
kubectl create -f topology.yaml
```

The pod won't got scheduled and is always pending.
