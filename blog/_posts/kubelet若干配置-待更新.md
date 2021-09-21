---
title: kubelet若干配置-待更新
date: 2021-07-25 15:03:16
tags: Kubernetes
---

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/西湖.jpg "5月3日在西湖")
                                   <center>5月3日在西湖</center>

记录一下，kubelet的若干配置，这些配置日常工作经常用到，记录待查。

- 修改runtime
修改K8S的runtime只需要修改kubelet的一些参数即可，假设kubelet是通过systemD管理并通过kubeadm安装的，如果通过binary启动修改起来则更简单（直接修改启动参数即可）。

```
systemctl status kubelet
   Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; vendor preset: enabled)
  Drop-In: /etc/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
```

可以看到它的服务对应的配置文件为`10-kubeadm.conf`,

```
cat 10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
...
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
...
EnvironmentFile=-/etc/default/kubelet
```

可以直接修改环境变量或者在引用的环境变量文件中定义加入下面这行，

```
KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint='unix:///run/containerd/containerd.sock' --image-service-endpoint='unix:///run/containerd/containerd.sock'
```

目前来说，默认的runtime还是docker，我们希望将其修改为containerd，CRIO的修改类似。

然后重新load服务的配置文件，并重启kubelet服务。

```
systemctl daemon-reload
systemctl restart kubelet
```

```
# kubectl get node -o wide
NAME           STATUS     ROLES                  AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
dave-desktop   Ready      control-plane,master   72d   v1.21.1   10.169.180.51    <none>        Ubuntu 18.04.3 LTS   4.15.0-46-generic   containerd://1.2.6
```

可以看到node的runtime已经修改为containerd了。

**NOTE**
默认的containerd的配置（通过Docker安装的默认配置）是没有enable cri服务的。

```
cat /etc/containerd/config.toml | grep disabled_plugins
disabled_plugins = ["cri"]
```

这里可以直接修改此配置文件，或者通过下面的命令来生成默认的containerd的配置。

```
containerd config default > /etc/containerd/config.toml
```

reload，重启containerd的服务即可。

否则，会遇到类似这样的错误而导致kubelet无法启动成功。
```
"Failed to run kubelet" err="failed to run Kubelet: failed to create kubelet: get remote runtime typed version failed: rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.RuntimeService"
```

- 修改cgroup driver

方法类似，例如我们修改driver为systemd，只需要在上面`KUBELET_EXTRA_ARGS`的配置里加上

```
--cgroup-driver="systemd"
```
reload， 重启服务即可。


- 修改node上可以run的pod的数量

默认一个node上可以跑110个pods，但这个是可以修改的。例如，我们希望修改这个配置为1500，那么只需要在10-kubeadm.conf中添加一个环境变量，像这样，


```
Environment="KUBELET_NODE_MAX_PODS=--max-pods=1500"
```

并将这个环境变量加入到服务启动的参数列表中去，

```
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS $KUBELET_NODE_MAX_PODS
```

reload， 重启服务即可。


我们来检查一下，

```
kubectl describe node ip-10-253-2-22

Capacity:
  cpu:                64
  ephemeral-storage:  508184812Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             261120516Ki
  pods:               1500
Allocatable:
  cpu:                64
  ephemeral-storage:  468343121964
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             261018116Ki
  pods:               1500
```

可以看到Capacity以及Allocatable对应的pods数量都修改为1500。


