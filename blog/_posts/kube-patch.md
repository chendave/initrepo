---
title: Kubernetes Patch 学习小结
date: 2018-05-20 10:00:12
thumbnail: /css/images/patch.jpg
tags: Kubernetes
---

总结一下`Kubernetes Patch`的使用方法，详细的说明还要要去看官网[1]，K8S用这个命令来对运行中的应用进行动态跟新。总的来说`Patch`一个API对象有三种方式：

- 使用JSON Patch来更新一个对象，没有看到具体的例子，看起来这是JSON的一个标准[2]，类似数据库的增删改查的方式对原来的JSON格式进行修改，不太清楚K8S对其支持如何。
- 使用JSON merge patch，这种方式需要定义一个完整的替换列表，也就是说，新的列表定义会替换原有的定义。
- 使用JSON strategic merge patch，这种补丁是以增量的形式来对已有的定义进行修改，可以理解为类似于`linux diff`创建的补丁。


下面对第二种和第三种形式的更新，分别来举个栗子：


#### JSON merge patch

下面的例子用来部署一个`nginx`应用，2份拷贝，后面在此基础上打补丁

``` yaml
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: patch-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: patch-demo-ctr
        image: nginx
      tolerations:
      - effect: NoSchedule
        key: dedicated
        value: test-team
```

先部署这个应用：

``` bash
$ kubectl create -f patch_demo.yaml
$ kubectl get pod -o wide

NAME                         READY     STATUS    RESTARTS   AGE       IP             NODE
patch-demo-576f89c99-mf4fj   1/1       Running   0          1m        10.244.2.118   k8s-node2
patch-demo-576f89c99-tb97t   1/1       Running   0          1m        10.244.1.185   k8s-node1
```

可以两个pod都已经跑了起来，接下来想对image进行修改，定义下面的patch:
``` yaml
spec:
  template:
    spec:
      containers:
      - name: patch-demo-ctr-3
        image: gcr.io/google-samples/node-hello:1.0
```

``` bash
$ kubectl patch deployment patch-demo --type merge --patch "$(cat patch_image.yaml)"
$ kubectl get pod -o wide
patch-demo-86c8577c88-bgd9s   1/1       Running   0          9m        10.244.2.119   k8s-node2
patch-demo-86c8577c88-qqfrv   1/1       Running   0          10m       10.244.1.187   k8s-node1
```

对比pod ID可见已有的pod已经被terminate了，并重新创建了两个新的 pod，可以进一步查看更新后的image：

``` bash
$ kubectl get deployment patch-demo --output yaml | grep image
      - image: gcr.io/google-samples/node-hello:1.0
        imagePullPolicy: IfNotPresent
```




#### JSON strategic merge patch

所谓策略性补丁，就是作为一个对已有配置的增量补丁，想想`diff`就好了，patch中没有定义的修改内容，则不会对原有配置产生影响，还是看下这个例子，基于原始版本新增一个新的`redis`的容器，定义好下面的补丁：

``` yaml
spec:
  template:
    spec:
      containers:
      - name: patch-demo-ctr-2
        image: redis
```

``` bash
$ kubectl patch deployment patch-demo --patch "$(cat patch_container.yaml)"
deployment "patch-demo" patched

$ kubectl get pod -o wide
NAME                          READY     STATUS    RESTARTS   AGE       IP             NODE
patch-demo-74b9844b77-hk2l7   2/2       Running   0          3m        10.244.2.120   k8s-node2
patch-demo-74b9844b77-qjz6r   2/2       Running   0          5m        10.244.1.188   k8s-node1
```

`2/2`表示每个pod有两个容器，如果想再看细点，用下面命令来查看pod上跑的image:

``` bash
$ kubectl get pod patch-demo-74b9844b77-hk2l7 --output yaml | grep image
  - * image: redis *
    imagePullPolicy: Always
  - * image: gcr.io/google-samples/node-hello:1.0 *
    imagePullPolicy: IfNotPresent
    image: redis:latest
    imageID: docker-pullable://redis@sha256:4aed8ea5a5fc4cf05c8d5341b4ae4a4f7c0f9301082a74f6f9a5f321140e0cd3
    image: gcr.io/google-samples/node-hello:1.0
    imageID: docker-pullable://gcr.io/google-samples/node-hello@sha256:d238d0ab54efb76ec0f7b1da666cefa9b40be59ef34346a761b8adc2dd45459b
```

好了，先总结到这里，详细的介绍还是看官网吧，下周再来看看。



---
[1] https://kubernetes.io/docs/tasks/run-application/update-api-object-kubectl-patch/
[2] http://erosb.github.io/post/json-patch-vs-merge-patch/
