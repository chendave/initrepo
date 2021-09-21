---
title: Kubernetes 环境搭建与 proxy设置
thumbnail: /css/images/鲁迅公园.jpg
date: 2018-04-06 22:53:38
tags: Kubernetes
---

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/鲁迅公园.jpg "")
从18年开始，计划投入大力气学习Kubernetes，毕竟还是想走云计算这条路，当技术变革来临之时，与其被拍在沙滩上还不如伸开双手去拥抱。

既然下定决心去学习Kubernetes，那就得脚踏实地的去做点事情，搭建一个实验的Kubernetes 集群算作是第一步吧。

## 为什么要设置代理
接触到第一个部署Kubernetes的工具是kubeadm，用Kubernetes 搭建一个集群官网[1]有比较详细的描述，步骤也比较简单，这里不打算重复kubeadm的几个命令，而是着重吐槽一下有关代理设置这一问题，在我们伟大的祖国，想做点事，代理就越发凸显出它的重要性，谁让这些开源技术都是人家美帝弄出来的？言归正传，搭建Kubernetes 必须要用到proxy，这是因为很多docker的image都是由Google在维护，即便不是，为了image的下载速度还可以接受，我们也得有个梯子。

### 设置终端代理

在执行**kubeadm init**去初始化master节点之前，用下面的命令去设置终端代理：
``` bash
$ export http_proxy=http://$username:$password@$proxy_host:$port
$ export https_proxy=https://$username:$password@$proxy_host:$port
$ export no_proxy=127.0.0.1,localhost,192.168.2.100
```

192.168.2.100是master节点的物理IP。

### 设置docker的代理
初始化的过程中是要通过docker去下载image，没有代理去下载？你就去等吧，等吧，终于等到timeout。

可以去docker的官网去看如何为docker设置代理，这里记录我在实验环境里的设置，或许还需要用相同的方式创建一个https的proxy文件。

``` bash
$ mkdir -p /etc/systemd/system/docker.service.d

$ cat /etc/systemd/system/docker.service.d/http-proxy.conf

[Service]     
Environment="HTTP_PROXY=http://$username:$password@$proxy_host:$port" "NO_PROXY=localhost,127.0.0.1,192.168.2.100"
```

### 初始化master节点
既然代理都已经设置好了（其实这里有一个坑，很大的一个坑 ^^），来点真格的吧。

``` bash
# kubeadm init --apiserver-advertise-address 192.168.2.100 --pod-network-cidr=10.244.0.0/16
```

给出来的是下面一堆输出：
``` bash
[init] Using Kubernetes version: v1.9.3
[init] Using Authorization modes: [Node RBAC]
[preflight] Running pre-flight checks.
        [WARNING FileExisting-crictl]: crictl not found in system path
        [WARNING HTTPProxyCIDR]: connection to "10.96.0.0/12" uses proxy "http://\$username:\$password@\$proxy_host:$port". This may lead to malfunctional cluster setup. Make sure that Pod and Services IP ranges specified correctly as exceptions in proxy configuration
...
You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/


You can now join any number of machines by running the following on each node
as root:
  kubeadm join --token 5076b0.10c90eec17e4a2a3 192.168.2.100:6443 --discovery-token-ca-cert-hash sha256:b7cdd4209d7357a020d29ca92f9b99ce1b671cd2fe841ca24ff7114e50f8778f
```

嗯，虽然有两个warning，但还是命令执行成功了。十年来的IT“从业经验”告诉我，警告看的多了，你吓唬的了谁？你看不是最终还是成功了么？

接着添加其它两个node节点到K8S的cluster里，还是成功！

耍一把K8S的命令行工具，依然是成功！

``` bash
$ kubectl get nodes
NAME        STATUS    ROLES     AGE       VERSION
k8s-node1   Ready     <none>    10d       v1.9.6
k8s-node2   Ready     <none>    8d        v1.9.3
k8smaster   Ready     master    10d       v1.9.3
```

直到有一天我要去查看pod的日志文件：
``` bash
$ kubectl logs -f httpd-7448fc6b46-6pf7w
	Error from server: Get https://192.168.18.111:10250/containerLogs/default/httpd-7448fc6b46-6pf7w/httpd?follow=true: cannotconnect
```

然而访问master节点上的日志却正常，pod也运行正常，通过curl也可以正常访问。

尝试K8S的dashboard，虽然可以安装成功，但页面访问给出的也是一样的提示**cannotconnect**，百思不得其解啊，你到是为什么**cannotconnect**？！！ sun of the beach !!

直觉告诉我，这又是一个proxy设置的问题，但无论如何也想不到错在哪里，终于有那么一天，当我老老实实的复盘时，我不得不再次审视那几个warning。
``` bash
[preflight] Running pre-flight checks.
        [WARNING FileExisting-crictl]: crictl not found in system path
        [WARNING HTTPProxyCIDR]: connection to "10.96.0.0/12" uses proxy "http://\$username:\$password@\$proxy_host:$port". This may lead to malfunctional cluster setup. Make sure that Pod and Services IP ranges specified correctly as exceptions in proxy configuration
```

恍然大悟，**no_proxy**, 不光是这里的"10.96.0.0/12"（虽然到现在我也不知道这个网络是给谁用的，-_-||），给docker设置proxy时，各个slave节点的IP也得在no_proxy的设置范围内，回过头来看，我们的proxy设置应该想像下面这样，其中192.168.18.111,192.168.18.75是slave节点的物理IP地址。

``` bash

# 终端proxy
$ export no_proxy=127.0.0.1,localhost,192.168.2.100，192.168.18.111,10.96.0.0/12,192.168.18.75,10.244.0.0/16
# docker 代理
$ cat /etc/systemd/system/docker.service.d/http-proxy.conf

[Service]     
Environment="HTTP_PROXY=http://$username:$password@$proxy_host:$port" "NO_PROXY=localhost,127.0.0.1,192.168.2.100，192.168.18.111,192.168.18.75,10.244.0.0/16"
```

通过下面的命令，让配置的代理生效：

``` bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

确认更新后的代理设置：

``` bash
systemctl show docker --property Environment
```

再去试试CURL，dashboard，kubectl logs一切如你所愿！

---
[1] https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm
