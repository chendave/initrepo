---
title: Kubernetes - HA and LB cluster setup
date: 2021-11-09 11:07:45
thumbnail: /css/images/mid-autumn.jpg
tags: Kubernetes
---

分布式系统的HA和LB一直是一个关键性技术点，Kubernetes也有许多方面的考虑和实现来支持HA/LB，比方说lease，网络流量方面的LB（kube-proxy），以及在整体架构上与业界比较通用的haproxy与keepalived解决方案的集成，其它第三方的项目包括kube-vip, nginx-ingress等。

本文记录一下在与haproxy以及keepalived做集成的一些关键性的问题和配置。一个最简单的实验需要至少3个控制节点外加一个计算节点。

考虑HA/LB主要考虑的是控制面上的一些服务，例如kube-apiserver，etcd，kube-scheduler以及kube-controller-manager。

- kube-apiserver是整个cluster的入口，各种状态查询，pod的CRUD都需要通过apiserver来接入，所以需要重点考虑，在我们的实验中我们引入haproxy对apiserver做负载均衡，在引入keepalived对haproxy做HA。
- kube-scheduler 与kube-controller-manager相对于apiserver来说压力较小，例如scheduler只需要对pod的创建做出响应，所以直接采用lease机制即可。
- etcd支持创建一个etcd的cluster，可以直接调用etcd的CLI添加一些新的member。etcd可以是和控制节点集成在一起（stacked etcd cluster）也可以独立在其它的节点上(external etcd cluster)，参考官方文档 - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/


![ha-topology-stacked-etcd](https://github.com/chendave/chendave.github.io/raw/master/css/images/kubeadm-ha-topology-stacked-etcd.svg "")

![ha-topology-external-etcd](https://github.com/chendave/chendave.github.io/raw/master/css/images/kubeadm-ha-topology-external-etcd.svg "")



## lease机制

首先来看看lease机制，或者说是leader-election机制，[client-go例子](https://github.com/kubernetes/client-go/blob/master/examples/leader-election/main.go).
其本质是在竞争创建一个LeaseLock的object, 服务可以在多台机器上同时启动，但最终只有一个服务能成功抢占并创建这个lease对象。

```golang
// https://github.com/kubernetes/client-go/blob/9b0b23a8ade2b5323d6624146cea2ad7b8928f25/tools/leaderelection/leaderelection.go#L327-L341

oldLeaderElectionRecord, oldLeaderElectionRawRecord, err := le.config.Lock.Get(ctx)
	if err != nil {
		if !errors.IsNotFound(err) {
			klog.Errorf("error retrieving resource lock %v: %v", le.config.Lock.Describe(), err)
			return false
		}
		if err = le.config.Lock.Create(ctx, leaderElectionRecord); err != nil {
			klog.Errorf("error initially creating leader election record: %v", err)
			return false
		}

		le.setObservedRecord(&leaderElectionRecord)

		return true
	}

```


再来看看scheduler的相关代码，

```golang
// go/src/k8s.io/kubernetes/cmd/kube-scheduler/app/server.go

	if cc.LeaderElection != nil {
		cc.LeaderElection.Callbacks = leaderelection.LeaderCallbacks{
			OnStartedLeading: func(ctx context.Context) {
				close(waitingForLeader)
				sched.Run(ctx)
			},
			OnStoppedLeading: func() {
				select {
				case <-ctx.Done():
					// We were asked to terminate. Exit 0.
					klog.InfoS("Requested to terminate, exiting")
					os.Exit(0)
				default:
					// We lost the lock.
					klog.Exitf("leaderelection lost")
				}
			},
		}
		leaderElector, err := leaderelection.NewLeaderElector(*cc.LeaderElection)
		if err != nil {
			return fmt.Errorf("couldn't create leader elector: %v", err)
		}

		leaderElector.Run(ctx)

		return fmt.Errorf("lost lease")
	}

```

而`leaderElector.Run(ctx)`最后也是一样调用`le.acquire(ctx)`来尝试创建lease对象。

在多个scheduler或者controller manager的情况下，如何判断那个节点的服务是生效的？

```bash
kubectl get lease -A

NAMESPACE          NAME                     HOLDER                                         AGE
kube-node-lease   master1                   master1                                        13d
kube-node-lease   master2                   master2                                        13d
kube-node-lease   master3                   master3                                        13d
kube-system       kube-controller-manager   master3_cb2b887c-71b4-4fca-9fea-9bab10279502   13d
kube-system       kube-scheduler            master2_a741b6df-5833-4dc5-bf5d-6755709cbe1e   13d   
```


可以看到获取到lease的kube-scheduler是跑在master2这个节点上的。kube-controller-manager  是master3这个节点上的。


apiserver的HA/LB与haproxy和keepalived的集成主要是一些服务配置，
- haproxy需要在每一个controller上面安装，目的是一个机器上的haproxy宕掉之后，可以结合keepalived让其它节点上的haproxy继续工作。
- keepalived需要在每一个controller上面安装，keepalived的目的是提供一个VIP，或者说是一个浮动IP。
- 以kubeadm的安装为例，首个节点需要control-plane-endpoint来指定控制节点的endpoint，即VIP+haproxy bind的端口。首个节点部署成功的时候会输出join其它控制节点命令。
- 其它控制节点在加入cluster时指定的endpoint不再是某个node上的物理IP，而是VIP+haproxy bind。这样只要保证VIP是可以联通的，某个节点到宕掉不影响整个cluster的工作。
- 加入其它结点之前需要先同步密钥和证书，这部分现在是手动做的，个人觉得上游社区是不会接受将其自动化处理的，因为这步操作会修改文件系统上的文件，上游应该会觉得这部分不应该归他们管吧。这部分文件包括（ca.crt，ca.key，sa.key，sa.pub，front-proxy-ca.crt，front-proxy-ca.key，etcd/ca.crt，etcd/ca.key） 


## haproxy与keepalived配置

下面列出haproxy以及keepalived的配置，每个节点上的配置保持相同，并对需要注意的点加以说明，

```conf
/etc/haproxy/haproxy.cfg(see: https://github.com/chendave/initrepo/tree/master/ha)

frontend kubernetes-apiserver
    bind *:16443  [1]
    mode tcp    [2]
    option tcplog
    default_backend kubernetes-apiserver

backend kubernetes-apiserver
    mode tcp
    balance roundrobin  [3] 
    server master 10.169.180.51:6443 check [4]
    server master1 10.169.212.212:6443 check
    server master2 10.169.182.17:6443 check
```


[1] 这里可以绑定任何不冲突的端口，后面我们用kubeadm在bootstrap其它节点时用的都是这个端口。
[2] 这里需要走tcp协议而不能用http [haproxy-http-vs-tcp](https://serverfault.com/questions/611272/haproxy-http-vs-tcp) 有做解释，apiserver走的是https协议，所以如果用http的话会出错。
[3] 参考[configuration](https://www.haproxy.org/download/2.5/doc/configuration.txt) 文档的说明，现在有多达10个算法，在我的实验里用了最普通的roundrobin。
[4]  后端对应的apiserver应该是物理IP加6443，无论前端bind的port是多少，6443是一定会在每个机器上存在的，这也是能balance的一个关键所在，注意VIP是独立的和服务原生的IP以及端口不是替换的关系。

>      roundrobin  Each server is used in turns, according to their weights.
>                  This is the smoothest and fairest algorithm when the server's
>                  processing time remains equally distributed. This algorithm
>                  is dynamic, which means that server weights may be adjusted
>                  on the fly for slow starts for instance. It is limited by
>                  design to 4095 active servers per backend. Note that in some
>                  large farms, when a server becomes up after having been down
>                  for a very short time, it may sometimes take a few hundreds
>                  requests for it to be re-integrated into the farm and start
>                  receiving traffic. This is normal, though very rare. It is
>                  indicated here in case you would have the chance to observe
>                  it, so that you don't worry.



```bash
# netstat -anp | grep  6443
tcp        0      0 0.0.0.0:16443           0.0.0.0:*               LISTEN      13015/haproxy
tcp        0      0 10.169.180.90:16443     10.169.212.212:48064    ESTABLISHED 13015/haproxy
tcp6       0      0 :::6443                 :::*                    LISTEN      21206/kube-apiserve
tcp6       0      0 10.169.180.51:6443      10.169.180.51:40086     ESTABLISHED 21206/kube-apiserve
```

再来看看keepalived的配置，每个机器上的配置稍有不通，主要在于如何合理的调整权重，可以参考github上的配置（https://github.com/chendave/initrepo/tree/master/ha）。

```conf
! Configuration File for keepalived

global_defs {
   router_id master1   [1]
}

vrrp_script chk_haproxy {
    script "/bin/bash -c 'if [[ $(netstat -nlp | grep 16443) ]]; then exit 0; else exit 1; fi'"  # haproxy 检测 [2]
    interval 2  # 每2秒执行一次检测
    weight 20 # 权重变化 [3]
}

vrrp_instance VI-kube-master {
    state MASTER  [4]
    interface eth0   [5]
    virtual_router_id 50
    priority 100 [6]
    unicast_src_ip 10.169.180.51 [6]
    unicast_peer {
        10.169.212.212      [7] peers
        10.169.182.17
    }
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }

    track_script {
        chk_haproxy
    }

    virtual_ipaddress {
        10.169.180.90/22
    }
}
```

[1] 保证每个机器的`router_id`互不相同。
[2] 引入keepalived的目的是某一个haproxy挂了之后，能将VIP挂在其它节点上，所以这里加了一个脚本来检测haproxy是否还活着。
[3] weight和priority一起决定最后的VIP挂在哪个物理机上，算法可以查看keepalived的说明。
通过weight和priority的调整，来做到当一个机器上的haproxy服务停止之后，VIP可以在其它机器上次权重的机器上的挂起。
[4] 标志当前的状态，据说关系不大。
[5] VIP挂在哪个物理的nic之下。
[6] 本机的物理IP地址。
[7] 之所以使用unicast的原因是很多情况下multicast被禁，例如在工作场所，所以往往配置为multicast的时候，对端的节点无法获知对端是否已经绑定了VIP，结果就是网络里可能有多个VIP造成我们的实验失败。

在master1的节点上可以看到VIP已经被挂起，

```bash
root@master1 # ip a
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
	…
    inet 10.169.180.90/22 scope global secondary eth0
       valid_lft forever preferred_lft forever

# systemctl status keepalived.service
10月 30 18:16:23 master1 Keepalived_vrrp[32078]: VRRP_Instance(VI-kube-master) forcing a new MASTER election
10月 30 18:16:24 master1 Keepalived_vrrp[32078]: VRRP_Instance(VI-kube-master) Transition to MASTER STATE
10月 30 18:16:25 master1 Keepalived_vrrp[32078]: VRRP_Instance(VI-kube-master) Entering MASTER STATE

# ping -c 5 10.169.180.90
PING 10.169.180.90 (10.169.180.90) 56(84) bytes of data.
64 bytes from 10.169.180.90: icmp_seq=1 ttl=62 time=0.235 ms
64 bytes from 10.169.180.90: icmp_seq=2 ttl=62 time=0.178 ms
64 bytes from 10.169.180.90: icmp_seq=3 ttl=62 time=0.192 ms
64 bytes from 10.169.180.90: icmp_seq=4 ttl=62 time=0.185 ms
64 bytes from 10.169.180.90: icmp_seq=5 ttl=62 time=0.193 ms

root@master3:~# systemctl status keepalived.service
Nov 08 08:13:17 master3 Keepalived_vrrp[6165]: Using LinkWatch kernel netlink reflector...
Nov 08 08:13:17 master3 Keepalived_vrrp[6165]: VRRP_Instance(VI-kube-master) Entering BACKUP STATE
Nov 08 08:13:17 master3 Keepalived_vrrp[6165]: VRRP_Script(chk_haproxy) succeeded
Nov 08 08:13:18 master3 Keepalived_vrrp[6165]: VRRP_Instance(VI-kube-master) Changing effective priority from 80 to 100
```


## kubeadm bootstrap

看看我们用kubeadm来创建各个节点的命令。apiserver-cert-extra-sans的目的是让CLI可以在其它机器上也可以运行。

```bash
kubeadm init --control-plane-endpoint="10.169.180.90:16443" --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans=master2,10.169.180.90,master3 --upload-certs
```

加入其它controller节点，至少三个，
```bash
kubeadm join 10.169.180.90:16443 --token q1vi54.rqy34szr6xn56s0k \
        --discovery-token-ca-cert-hash sha256:dac15eaa52a6c9fff179693aea175df23719e6cb09d5a9281a3104148b13ebfb \
        --control-plane --certificate-key 1fb83358db692a50f9d0dd4c6658af8d46e2ee8f1921f37b180cce2ec3f0d51b

```

加入至少一个worker节点，

```bash
kubeadm join 10.169.180.90:16443 --token q1vi54.rqy34szr6xn56s0k \
        --discovery-token-ca-cert-hash sha256:dac15eaa52a6c9fff179693aea175df23719e6cb09d5a9281a3104148b13ebfb
```

检查是否多个控制节点都已经就绪.

```bash
root@master1:/etc/keepalived# kubectl get node
NAME                   STATUS                     ROLES                  AGE   VERSION
master1                Ready                      control-plane,master   13d   v1.21.1
master3                Ready                      control-plane,master   13d   v1.21.1
master2                Ready                      control-plane,master   13d   v1.21.2

root@master1:/etc/keepalived# kubectl get pod -n kube-system -o wide | grep kube-apiserver
kube-apiserver-master1            1/1     Running   3          10d   10.169.180.51    master1  <none>           <none>
kube-apiserver-master3            1/1     Running   0          10d   10.169.212.212   master3  <none>           <none>
kube-apiserver-master2            1/1     Running   3          12d   10.169.182.17    master2  <none>           <none>
```


## etcd 相关

kubeadm在处理etcd的时候并不复杂，简单来说就是创建static  pod所需要的yaml文件，并调用etcd的CLI将其它机器上的etcd的instance加入到etcd的cluster中去，

```golang
// /go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/join/controlplanejoin.go （以stack的模式为例）
if err := etcdphase.CreateStackedEtcdStaticPodManifestFile(client, data.ManifestDir(), data.PatchesDir(), cfg.NodeRegistration.Name, &cfg.ClusterConfiguration, &cfg.LocalAPIEndpoint, data.DryRun(), data.CertificateWriteDir()); err != nil {
return errors.Wrap(err, "error creating local etcd static pod manifest file")
}


// /go/src/k8s.io/kubernetes/cmd/kubeadm/app/util/etcd/etcd.go
cli, err := clientv3.New(clientv3.Config{
Endpoints:   c.Endpoints,
DialTimeout: etcdTimeout,
DialOptions: []grpc.DialOption{
grpc.WithBlock(), // block until the underlying connection is up
},
TLS: c.TLS,
})
```


而etcd的同步是基于raft算法，一个从paxos算法衍生的分布式数据库同步算法（有机会可以去深入分析一下）。


## 验证

几个基本的cases，
1.	停止某个节点上haproxy，VIP会浮动到次优节点，依然可以创建pods。
2.	在apiserver里打上log，创建多个pods，请求被发送到多个不同的控制节点上。
3.	停止某个节点上的scheduler服务，依然可以创建pods。


## Reference

-----------

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/
https://blog.csdn.net/chenleiking/article/details/84841394

