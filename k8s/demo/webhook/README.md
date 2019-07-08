This directory contains all the files that are needed to validate the Kubernetes admission webhook.

Concret steps are list below,

- Build an image for service by yourself.

```
cd $GOPATH/src/k8s.io/kubernetes/test/images
make all WHAT=webhook
docker login
docker tag gcr.io/kubernetes-e2e-test-images/webhook-amd64:1.14v1 jungler/webhook-amd64:1.14v1
docker push jungler/webhook-amd64:1.14v1
```

- Generate self-signed CA cert, priviate key and the cert that is signed by the CA cert, this could be done
by running the the `certs.go` under `$GOPATH/src/k8s.io/kubernetes/test/e2e/apimachinery`, the file just
modify a little bit based on the file in the tree to tell us where the cert/key is generated.

```bash
cd $GOPATH/src/k8s.io/kubernetes/test/e2e/apimachinery
go run certs.go
```

The files will be generated in the temporary directory, for example, `/tmp/test-e2e-server-cert870905509`

`gensecret.sh` is copied from [1], but it is lacking of self-signed CA cert, if go this approach, you need to
replace the `caBundle` (mentioned below) with the CA cert defined in the `/etc/kubernetes/kubelet.conf`.

- Create a K8S tls secret based on the generated cert and key.

```
kubectl create secret tls sample-webhook-secret --cert=/tmp/test-e2e-server-cert405184811/server.crt360522389 --key=/tmp/test-e2e-server-cert405184811/server.key791923952 --namespace=e2e-tests-webhook-gbgt6
```

- Encode the self-signed CA cert (pem formated).
As an example, do it as this,

```bash
cd /tmp/test-e2e-server-cert870905509
cat server-cert.pem | base64 -w 0
```

- Create `MutatingWebhookConfiguration`, replace `caBundle` with the output from last step.

```bash
kubectl create -f webhook-config.yaml
```

- Create a namespace.

```bash
kubectl create -f webhook-namespace.yaml
```

- Create `e2e-test-webhook` service.

```bash
kubectl create -f webhook-server.yaml
```

- Create a pod in the namespace and verify whether the initContainers is appended.

```bash
kubectl create -f pod.yaml
kubectl get pod webhook-to-be-mutated -n e2e-tests-webhook-gbgt6 -o yaml

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2019-07-07T04:12:47Z"
  name: webhook-to-be-mutated
  namespace: e2e-tests-webhook-gbgt6
  resourceVersion: "7122189"
  selfLink: /api/v1/namespaces/e2e-tests-webhook-gbgt6/pods/webhook-to-be-mutated
  uid: 7a850aab-a06d-11e9-97e5-6c3be511f343
...

  containers:
  - image: k8s.gcr.io/pause:3.1
    imagePullPolicy: IfNotPresent

...
  initContainers:
  - image: webhook-added-image
    imagePullPolicy: Always
...
  phase: Pending
  podIP: 10.244.0.86
  qosClass: BestEffort
  startTime: "2019-07-07T04:12:48Z"
```

**Note** webhook is an example from K8S's code base, you can get the details for how to run it as with code from here[3]


Reference:
---------
[1] https://github.com/morvencao/kube-mutating-webhook-tutorial/blob/master/deployment/webhook-create-signed-cert.sh

[2] https://juejin.im/post/5ba3547ae51d450e425ec6a5 (A blog written in Chinese)

[3] https://github.com/kubernetes/kubernetes/tree/master/test/e2e/apimachinery
