Pod disruption budgets is a feature to help you run highly available applications even when you introduce frequent voluntary disruptions.
NOTE: This is not truly guarantee but only enforce a additional check targeted for HA.

Here are some steps to play with,

1. Create 4 pods with label "name=hello",
```
kubectl create -f pod1.yaml
...

```


2. Create `PodDisruptionBudget` that want at least 3 pods available, 

```
kubectl create -f pdb.yaml
``` 

3. Check the status of `pdb`,
```
kubectl describe pdb test-pdb
Name:           test-pdb
Namespace:      default
Min available:  3
Selector:       name=hello
Status:
    Allowed disruptions:  1
    Current:              4
    Desired:              3
    Total:                4
Events:                   <none>
```

4. Remove 2 pods, and check the status again, 
```
kubectl describe pdb test-pdb
Name:           test-pdb
Namespace:      default
Min available:  3
Selector:       name=hello
Status:
    Allowed disruptions:  0
    Current:              2
    Desired:              3
    Total:                2
Events:                   <none>

kubectl get pdb
NAME       MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
test-pdb   3               N/A               1                     29m

```
