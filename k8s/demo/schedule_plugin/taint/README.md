`taint` is defined on node,
- kubectl taint nodes node1 key1=value1:NoSchedule

`toleration` is defined in the pod spec,
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  tolerations:
  - key: "key1"
    operator: "Exists"
    effect: "NoSchedule"
```

By default, the pod is not able to schedule to a tainted node (node1), unless
it has the toleration defined in pod spec, in the above example, the pod tolerate
the taint on the target node which has the taint key "key1", and effect is
"NoSchedule".



valid operator:
- Exists
- Equal
- empty string (same as Equal)

valid Effect
- NoSchedule
- PreferNoSchedule
- NoExecute

see reference for the details.


------
reference:
[1] https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
