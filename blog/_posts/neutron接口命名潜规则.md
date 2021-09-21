---
title: Neutron接口命名规则
date: 2018-07-28 19:38:12
tags: OpenStack
thumbnail: /css/images/xixi.jpg
---

这些日子上海挺热的，前些日子去杭州才发现，杭州比上海还要热个几度，大热天爆晒36+，带着老婆孩子去西溪湿地去暴走，这个天当然不适合旅游，只是往年都要找个日子去杭州来个短游，今年正好得去杭州去拜访吉利集团，可以理解为为了所谓的旅游而旅游吧。


*Neutron*已经看了有些日子了，计划不久的将来对有无DVR情况下南北与东西流量做个总结，当作一个铺垫吧，这里对Neutron里的网络接口命名做个小结，当看到*tap, qbr, qvb, qvo, qr-, qg-, br*前缀命令的接口设备有没有一点小晕呢？其实这些设备本质上都是一样的，但是应用的场景又各不相同，不同的名称前缀代表了不同的含义，所以熟悉了之后只看这些前缀也就略知一二了。


*tap-*
这个就是tap设备，每个虚拟机都对应一个tap设备，tap设备需要挂在linux bridge上或者OVS上，OpenStack里虚拟机的tap设备挂在linux bridge上，DHCP namespace里的tap设备挂在OVS上。
例如下面的tap设备"tap0cf5c0e2-26"来自于DHCP namespace并挂在OVS上。
``` bash
$ sudo ovs-vsctl show
    Bridge br-int
        Controller "tcp:127.0.0.1:6633"
            is_connected: true
        fail_mode: secure
..
        Port "tap0cf5c0e2-26"
            tag: 1
            Interface "tap0cf5c0e2-26"
                type: internal

```


``` bash
$ sudo ip netns exec qdhcp-2f0982cf-3f10-4ae5-96de-1e70d289fbf0 ip a
64: tap0cf5c0e2-26: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fa:16:3e:fb:9b:53 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.2/26 brd 10.0.0.63 scope global tap0cf5c0e2-26
       valid_lft forever preferred_lft forever
    inet6 fd7d:9d2b:8fb7:0:f816:3eff:fefb:9b53/64 scope global
       valid_lft forever preferred_lft forever
```


*qvb-*，*qvo-*与*qbr-*
qvb与qvo是一对veth pair，可以在系统上看到这一对veth pair，其中qvb设备挂在linux bridge上，qvo设备挂在OVS上。
我们可以通过在系统上输入ip a命令来查看这些veth pair的信息，例如我的系统上可以看到下面的设备：
``` bash
70: qvo285c68b1-9d@qvb285c68b1-9d: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1450 qdisc noqueue master ovs-system state UP group default qlen 1000
```

qbr用来定义命名一个linux bridge。

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/linux-bridge.png "")

*gr-*与*qg-*
qr设备用于连接租户网络（租户内部IP地址），qg设备用于连接外部网络（通过floating IP连接外部网络）。
例如：
``` bash
$ sudo ip netns exec qrouter-3b1a4673-4ada-4988-a11b-86fcacfb0ea0 ip a
65: qr-f937ae2f-ec: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fa:16:3e:ac:b9:00 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.1/26 brd 10.0.0.63 scope global qr-f937ae2f-ec
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:feac:b900/64 scope link
       valid_lft forever preferred_lft forever
66: qg-4386c8fb-38: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fa:16:3e:0d:5a:4d brd ff:ff:ff:ff:ff:ff
    inet 192.168.42.16/24 brd 192.168.42.255 scope global qg-4386c8fb-38
       valid_lft forever preferred_lft forever
    inet 192.168.42.11/32 brd 192.168.42.11 scope global qg-4386c8fb-38
       valid_lft forever preferred_lft forever
```


