steps:


1. Clone the hostpath GitHub repository

```
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
```

2. Apply VolumeSnapshot CRDs

```
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
```

3. Create snapshot controller

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.0/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.0/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```

4. Deployment

```
cd deploy/kubernetes-latest
./deploy.sh
```


5. Create Storage class
```
kubectl create -f sc.yaml
```


6. Create Volume Snapshot Class
```
kubectl create -f vsc.yaml
```

7. Create a test volume
```
kubectl create -f csi-pvc.yaml
```

8. Create a pod based on the PVC
```
kubectl create -f pod1.yaml
```


9. exec into the pod and write someting into the mount directory

```
kubectl exec -it podcsi /bin/sh
cd /mydata
touch hello_world
```


10. Create a snapshot

```
kubectl create -f snapshot.yaml
```

11. Create another a file in the mount directory

```
kubectl exec -it podcsi /bin/sh
cd /mydata
touch how_are_you
```

12. Restore volume from snapshot

```
kubectl create -f csi-restore.yaml
```

13. Create a pod based on the new volume
```
kubectl create -f pod2.yaml
```

14. Check that the new file does't show in the new pod


15. Try the inline ephemeral support

Volume is specified directly inside a pod spec without the need to use a persistent volume object.

```
kubectl create -f pod-ephemeral.yaml
```
