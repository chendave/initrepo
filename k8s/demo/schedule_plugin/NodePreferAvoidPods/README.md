- create `ReplicaSet`
  ```bash
  kubectl create -f replicaset.yaml
  ```

- create `ReplicationController` (should be fine with ReplicaSet)
  ```bash
  kubectl create -f replicationController.yaml
  ```

- Get the `ownerReferences`
  ```bash
  kubectl get pod nginx-6kd5c -oyaml
  ```

  ```yaml
  ownerReferences:
  - apiVersion: v1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicationController
    name: nginx
    uid: c8dad1cf-c3bb-4a1d-b0c9-fbe1a95248b6
  ```

- edit one of node to add the annotations
  ```bash
  kubectl edit node dell
  ```

  ```yaml
  metadata:
  annotations:
    flannel.alpha.coreos.com/backend-data: '{"VtepMAC":"86:34:70:d7:0f:1f"}'
    flannel.alpha.coreos.com/backend-type: vxlan
    flannel.alpha.coreos.com/kube-subnet-manager: "true"
    flannel.alpha.coreos.com/public-ip: 10.169.40.63
    kubeadm.alpha.kubernetes.io/cri-socket: /var/run/dockershim.sock
    node.alpha.kubernetes.io/ttl: "0"
    scheduler.alpha.kubernetes.io/preferAvoidPods: '{"preferAvoidPods":[{"podSignature":{"podController":{"apiVersion":"v1",
      "kind":"ReplicationController", "name":"nginx", "uid":"c8dad1cf-c3bb-4a1d-b0c9-fbe1a95248b6","controller":
      true}},"reason": "some test purpose","message": "for test purpose"}]}'
   ```

- delete one of pod from the `ReplicationController`, so it will re-schedulered, but this time the node will
  be less perferred.


- `kube-scheduler.yaml` config the weight of plugin in the config file, it will override the default weight "10000" defined in source.


Question:
any other usecase? this doesn't look like a right process to use it.
