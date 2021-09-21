---
title: OpenStack 与 SDN --- namespace 
date: 2018-04-30 16:20:33
thumbnail: /css/images/flower.png
tags: OpenStack
---

### 什么是network namespace ### 
先来看看linux手册上对namespace的解释
> A network namespace is logically another copy of the network stack, with its own routes, firewall rules, and network devices.
> By default a process inherits its network namespace from its parent. Initially all the processes share the same default network namespace from the init process.

翻译过来再加以理解，大致的意思就是network namespace实现了对网络资源的隔离，一个namespace有自己的路由，防火墙规则，以及网络设备。进程会从他的父进程那里继承network namespace。所有进程从共同的父进程init进程那里共享默认network namespace.

默认的network namespace有时也被称作root namespace，一个基本的原则是一个网络设备最终只能属于一个namespace，无论是物理设备或者虚拟设备。从实现上network namespace介于**chroot**与虚拟机VM之间，VM太重，而chroot不能有效实现网络设备隔离，如果想要实现的网络设备的隔离，那么优先考虑namespace。


从一张图来看或许更加清楚一些：
![](https://github.com/chendave/chendave.github.io/raw/master/css/images/namespace.png "")


### namespace与OpenStack ###
Neutron项目直接依赖于namespace，具体哪个版本引入不是太清楚了，如果你的环境是用*devstack*搭建起来的话，那么默认你是可以看到两个namespace的，

```bash
$ ip netns
qrouter-a781c60f-3929-4a2b-b233-d724f3693d4e
qdhcp-8c21785b-fdcf-49c6-8cf2-9ea56b9e8d35
```
可以看到一个提供路由功能，另一个提供DHCP服务，创建多个子网并设置DHCP服务可以在系统上创建对个DHCP namespace。
进入到namesapce内部来一探究竟。

```bash
$ sudo ip netns exec qrouter-a781c60f-3929-4a2b-b233-d724f3693d4e ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
42: qr-2e14aa33-ac: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fa:16:3e:88:7b:28 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.1/26 brd 10.0.0.63 scope global qr-2e14aa33-ac
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe88:7b28/64 scope link
       valid_lft forever preferred_lft forever
43: qg-9ad90b84-19: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fa:16:3e:33:37:8e brd ff:ff:ff:ff:ff:ff
    inet 192.168.42.139/25 brd 192.168.42.255 scope global qg-9ad90b84-19
       valid_lft forever preferred_lft forever
    inet 192.168.42.131/32 brd 192.168.42.131 scope global qg-9ad90b84-19
       valid_lft forever preferred_lft forever
    inet6 2001:db8::b/64 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe33:378e/64 scope link
       valid_lft forever preferred_lft forever
44: qr-9166b961-68: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fa:16:3e:11:5f:29 brd ff:ff:ff:ff:ff:ff
    inet6 fdbf:ae1d:a3f6::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe11:5f29/64 scope link
       valid_lft forever preferred_lft forever
```
对于router namespace来说*qr-2e14aa33-ac*其实就是一个内网的网关，*10.0.0.1/26*网段为内网网段，*qg-9ad90b84-19*则对应的是外网，其中*192.168.42.139*为外网网关，而其他IP地址则对应一个个用于访问外网的floating IP地址，他们共享一个虚拟的以太网地址或MAC地址。

dhcp namespace类似，其中除了一个回环设备外，剩下的就是一个IP地址就是DHCP服务器的IP地址。那么虚拟机是如何与他们产生联系的呢？答案是linux bridge或者OVS, 以OVS为例，这些虚拟的设备都会附加到*br-int* bridge上，对每一个虚拟机而言，又通过veth pair的方式附加到同一个bridge上以实现互联互通。不展开讨论。

OpenStack引入namespace的目的是为了解决多租户情况下的三层网络IP地址隔离，具体分析不用namespace的情况下可能会出现的问题可以参考这篇博文[1]




### namespace 访问外网 ###

谈到namespace对外网的访问，这里涉及到两个方面：
1. namespace内部网络设备比方说之前提到的 *qg-9ad90b84-19*设备对外网的访问。
2. 租户网络与外部网络之间的互访问。

第一个问题的答案之前已经提及，主要是通过将网络设备绑定到linux bridge或者OVS bridge来实现。
第二个问题的答案是floating IP与iptable，floating IP的本质只是通过iptable实现的一些虚拟IP而非物理的绑定到网卡上的IP地址，那么通过查看router上的iptable定义的规则，我们可以很清楚的了解到floating IP的实现原理。

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/namespace-iptables.png "")

上图中DNAT用于从外部网络访问虚拟机内部网络所定义的地址转换规则；SNAT用于从虚拟机内部网络访问外网是所需要的地址转换规则。


留下一个问题，namespace与LXC以及container这三者之间的关系是什么？留待下次总结。



---------
[1] https://blog.csdn.net/cloudman6/article/details/52876889
