---
title: Kubernetes Dashboard
date: 2018-06-18 12:32:53
tags: Kubernetes
thumbnail: /css/images/618.JPG
---

创建Kubernets Dashboard(UI)比较简单也就是几个命令的事儿，记录在这里作为一个备忘：

- 通过官网提供的yaml配置文件创建service, role, deployment等等:

``` bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

secret "kubernetes-dashboard-certs" created
serviceaccount "kubernetes-dashboard" created
role "kubernetes-dashboard-minimal" created
rolebinding "kubernetes-dashboard-minimal" created
deployment "kubernetes-dashboard" created
service "kubernetes-dashboard" created

```

-  启动kubectl proxy服务，API server将监听在8001端口，apiserver将负责访问控制：

``` bash
kubectl proxy --address='0.0.0.0' --port=8001 --accept-hosts='.*' &
```

**--address='0.0.0.0'** 使得其它机器也可以访问8001端口，**--accept-hosts** 让apiserver接受其它所有机器的请求。

- 赋予Dashboard的serviceaccount以admin权限，亦或理解为直接绕过访问控制？因为我的环境是直接通过kubeadm安装的，所以可以创建一个文件名为dashboard-admin.yaml，文件内容如下：

``` bash
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
```

执行下面的命令：

``` bash
kubectl create -f dashboard-admin.yaml
clusterrolebinding "kubernetes-dashboard" created
```

接下来就可以直接8001直接访问UI了，对于出现的用户认证页面，直接skip就好了，看到的界面看起来像这样：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/k8s-ui.png "")


---
[1] https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
[2] https://github.com/kubernetes/dashboard/wiki/Access-control
