---
title: （转）初探Openstack Neutron DVR
date: 2018-10-21 15:26:18
thumbnail: /css/images/forward.jpg
tags: OpenStack
---

这篇文章总结的很好了，偷懒直接转过来，以便日后不时查看。


首先看一下，没有使用DVR的问题在哪里：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/issues.png "")


从图中可以明显看到东西向和南北向的流量会集中到网络节点，这会使网络节点成为瓶颈。

那如果启用的DVR，情况会变成如下：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/dvr.png "")

对于东西向的流量， 流量会直接在计算节点之间传递。
对于南北向的流量，如果有floating ip，流量就直接走计算节点。如果没有floating ip，则会走网络节点。


我的实验环境如下：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/lab.png "")

然后起了两个私有网络和一个DVR 路由器，拓扑如下:

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/network.png "")


注:
可以看到每个网络与DVR连接时有两个接口，以private1为例，有10.0.1.1和10.0.1.6。

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/interface1.png "")

可以看到10.0.1.6是centralized_snat的网关，这个地址是在网络节点上的。
10.0.1.1是router_interface_distributed地址，它是在每一个计算节点上的。虚机获取到的默认网关就是这个IP。


虚机情况如下：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/interface2.png "")

注: 
虚机privateX-computeY-VM表示，此虚机起在privateX网络，computeY节点上。在compute1节点的两台虚机拥有floating ip。


下面分析三种情况下traffic的是怎么走的：
1. 东西向流量：以private1-compute1-VM和private2-compute2-VM之间的通信为例。
2. 南北向流量：
    a) 带floating ip， 以private1-compute1-VM对外通信为例。
    b) 不带floating ip， 以private1-compute2-VM对外通信为例。





第一种情况 -- 东西向流量
首先我们看一下虚机private1-compute1-VM的IP和路由:

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/we1.png "")


再看一下虚机private2-compute2-VM的IP和路由:


![](https://github.com/chendave/chendave.github.io/raw/master/css/images/we2.png "")



我们在private1-compute1-VM中ping 10.0.2.5(private2-compute2-VM的IP)。

当我们ping了之后，在首先会查询private1-compute1-VM的路由表，会将包发送到网关10.0.1.1。那么会首先会发送10.0.1.1的arp请求。
arp请求会发送到br-int上。
我们可以看到10.0.1.5的port id是4e843b99开头的：


![](https://github.com/chendave/chendave.github.io/raw/master/css/images/interface3.png "")

最终会转发到br-int的qvo4e843b99-fb:

``` bash
root@dvr-compute1:~# ovs-vsctl show
67f121bd-cca7-41c2-95ab-23ed85d1305b
    Bridge br-tun
        Port patch-int
            Interface patch-int
                type: patch
                options: {peer=patch-tun}
        Port "vxlan-0ae09f91"
            Interface "vxlan-0ae09f91"
                type: vxlan
                options: {df_default="true", in_key=flow, local_ip="10.224.159.141", out_key=flow, remote_ip="10.224.159.145"}
        Port "vxlan-0ae09f88"
            Interface "vxlan-0ae09f88"
                type: vxlan
                options: {df_default="true", in_key=flow, local_ip="10.224.159.141", out_key=flow, remote_ip="10.224.159.136"}
        Port br-tun
            Interface br-tun
                type: internal
    Bridge br-int
        fail_mode: secure
        Port "qvo111517d8-c5"
            tag: 2
            Interface "qvo111517d8-c5"
        Port patch-tun
            Interface patch-tun
                type: patch
                options: {peer=patch-int}
        Port "qr-001d0ed9-01"
            tag: 2
            Interface "qr-001d0ed9-01"
                type: internal
        Port br-int
            Interface br-int
                type: internal
        Port "qr-ddbdc784-d7"
            tag: 1
            Interface "qr-ddbdc784-d7"
                type: internal
        Port "qvo4e843b99-fb"
            tag: 1
            Interface "qvo4e843b99-fb"
    Bridge br-ex
        Port br-ex
            Interface br-ex
                type: internal
        Port "fg-081d537b-06"
            Interface "fg-081d537b-06"
                type: internal
    ovs_version: "2.0.2"
```


而端口qvo4e843b99-fb是属于vlan 1的，arp广播包会转发到"qr-ddbdc784-d7"和"patch-tun"。

首先看"qr-ddbdc784-d7"，这是interface_distributed的接口：


![](https://github.com/chendave/chendave.github.io/raw/master/css/images/interface4.png "")

这个接口是在compute node的的DVR中的：

``` bash
root@dvr-compute1:~# ip netns
fip-fbd46644-c70f-4227-a414-862a00cbd1d2
<font color=DarkRed size=5>qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa</font>
qdhcp-401f678d-4518-446c-9a33-cd2fb054c104
qdhcp-db755841-0764-4a8f-b962-8df008ce6330



root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ifconfig
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)


qr-001d0ed9-01 Link encap:Ethernet  HWaddr fa:16:3e:69:b4:05  
          inet addr:10.0.2.1  Bcast:10.0.2.255  Mask:255.255.255.0
          inet6 addr: fe80::f816:3eff:fe69:b405/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:35 errors:0 dropped:0 overruns:0 frame:0
          TX packets:14 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:3510 (3.5 KB)  TX bytes:1092 (1.0 KB)


<font color=DarkRed size=5>
qr-ddbdc784-d7 Link encap:Ethernet  HWaddr fa:16:3e:66:13:af  
          inet addr:10.0.1.1  Bcast:10.0.1.255  Mask:255.255.255.0
          inet6 addr: fe80::f816:3eff:fe66:13af/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:401 errors:0 dropped:0 overruns:0 frame:0
          TX packets:378 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:38224 (38.2 KB)  TX bytes:36224 (36.2 KB)
</font>


rfp-0fbb351e-a Link encap:Ethernet  HWaddr ea:5c:56:9a:36:9c  
          inet addr:169.254.31.28  Bcast:0.0.0.0  Mask:255.255.255.254
          inet6 addr: fe80::e85c:56ff:fe9a:369c/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:12 errors:0 dropped:0 overruns:0 frame:0
          TX packets:12 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:1116 (1.1 KB)  TX bytes:1116 (1.1 KB)
```

接口qr-ddbdc784-d7拥有10.0.1.1。所以他会响应ARP请求。



回过头来看"patch-tun", ARP请求转发到这个接口后，会转发到br-tun。看一下br-tun上的flow, 目前我们只需要看红色部分，他会将目标地址为10.0.1.1的ARP请求丢弃：

``` bash
root@dvr-compute1:~# ovs-ofctl dump-flows br-tun 
NXST_FLOW reply (xid=0x4): 
。。。
cookie=0x0, duration=64720.432s, table=1, n_packets=4, n_bytes=168, idle_age=64607, priority=3,arp,dl_vlan=1,arp_tpa=10.0.1.1 actions=drop 
cookie=0x0, duration=62666.766s, table=1, n_packets=2, n_bytes=84, idle_age=62576, priority=3,arp,dl_vlan=2,arp_tpa=10.0.2.1 actions=drop 
。。。
```

回到我们虚机，当获取到了10.0.1.1的MAC地址后，会发出如下的包：
Dest IP: 10.0.2.5
Souce IP: 10.0.1.5
Dest MAC: MAC of 10.0.1.1
Source MAC: MAC of 10.0.1.5


之后包被转发到compute1的qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa 的namespace：
这里利用了内核的高级路由到了，首先看一下ip rule：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip rule 
0: from all lookup local 
32766: from all lookup main 
32767: from all lookup default 
32768: from 10.0.1.5 lookup 16 
32769: from 10.0.2.3 lookup 16 
167772417: from 10.0.1.1/24 lookup 167772417 
167772417: from 10.0.1.1/24 lookup 167772417 
167772673: from 10.0.2.1/24 lookup 167772673 


可以看到会先查找main表：  
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip route list table main 
10.0.1.0/24 dev qr-ddbdc784-d7 proto kernel scope link src 10.0.1.1 
10.0.2.0/24 dev qr-001d0ed9-01 proto kernel scope link src 10.0.2.1 
169.254.31.28/31 dev rfp-0fbb351e-a proto kernel scope link src 169.254.31.28


在main表中满足以下路由:
10.0.2.0/24 dev qr-001d0ed9-01 proto kernel scope link src 10.0.2.1 
因此会从qr-001d0ed9-01转发出去。

之后需要去查询10.0.2.5的MAC地址， MAC是由neutron使用静态ARP的方式设定的：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip nei 
10.0.1.5 dev qr-ddbdc784-d7 lladdr fa:16:3e:da:75:6d PERMANENT 
10.0.2.3 dev qr-001d0ed9-01 lladdr fa:16:3e:a4:fc:98 PERMANENT 
10.0.1.6 dev qr-ddbdc784-d7 lladdr fa:16:3e:9f:55:67 PERMANENT 
10.0.2.2 dev qr-001d0ed9-01 lladdr fa:16:3e:13:55:66 PERMANENT
<font color=DarkRed size=4>10.0.2.5 dev qr-001d0ed9-01 lladdr fa:16:3e:51:99:b8 PERMANENT</font>
10.0.1.4 dev qr-ddbdc784-d7 lladdr fa:16:3e:da:e3:6e PERMANENT 
10.0.1.7 dev qr-ddbdc784-d7 lladdr fa:16:3e:14:b8:ec PERMANENT 
169.254.31.29 dev rfp-0fbb351e-a lladdr 42:0d:9f:49:63:c6 STALE

由于Neutron知道所有虚机的信息，因此他可以事先设定好静态ARP。
至此，我们的ICMP包会变成以下形式从qr-001d0ed9-01转发出去：
Dest IP: 10.0.2.5
Souce IP: 10.0.1.5
Dest MAC: MAC of 10.0.2.5
Source MAC: MAC of 10.0.2.1


当包转发到"br-tun"后，进开始查询openflow表。
首先我们看一下br-tun的接口状况：
root@dvr-compute1:~# ovs-ofctl show br-tun
OFPT_FEATURES_REPLY (xid=0x2): dpid:0000e2b7aa5da34a
n_tables:254, n_buffers:256
capabilities: FLOW_STATS TABLE_STATS PORT_STATS QUEUE_STATS ARP_MATCH_IP
actions: OUTPUT SET_VLAN_VID SET_VLAN_PCP STRIP_VLAN SET_DL_SRC SET_DL_DST SET_NW_SRC SET_NW_DST SET_NW_TOS SET_TP_SRC SET_TP_DST ENQUEUE
 1(patch-int): addr:76:ae:9f:b3:bf:c6
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 3(vxlan-0ae09f88): addr:92:61:e9:43:dd:99
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 4(vxlan-0ae09f91): addr:2e:cc:c0:4a:4e:d4
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 LOCAL(br-tun): addr:e2:b7:aa:5d:a3:4a
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
OFPT_GET_CONFIG_REPLY (xid=0x4): frags=normal miss_send_len=0


首先我们看一下br-tun的flowtable，首先会进入table 0，由于包是从br-int发过来的，因此in_port是patch-int(1)，之后会查询表1：
 cookie=0x0, duration=66172.51s, table=0, n_packets=58, n_bytes=5731, idle_age=20810, hard_age=65534, priority=1,in_port=3 actions=resubmit(,4)
 cookie=0x0, duration=67599.526s, table=0, n_packets=273, n_bytes=24999, idle_age=1741, hard_age=65534, priority=1,in_port=1 actions=resubmit(,1)
 cookie=0x0, duration=64437.052s, table=0, n_packets=28, n_bytes=2980, idle_age=20799, priority=1,in_port=4 actions=resubmit(,4)
 cookie=0x0, duration=67601.704s, table=0, n_packets=5, n_bytes=390, idle_age=65534, hard_age=65534, priority=0 actions=drop


表1，这张表中会丢弃目标地址是interface_distributed接口的ARP和目的MAC是interface_distributed的包。以防止虚机发送给本地IR的包不会被转发到网络中。
我们的ICMP包会命中一下flow，它会把源MAC地址改为全局唯一和计算节点绑定的MAC:
 cookie=0x0, duration=66135.811s, table=1, n_packets=140, n_bytes=13720, idle_age=65534, hard_age=65534, priority=1,dl_vlan=1,dl_src=fa:16:3e:66:13:af actions=mod_dl_src:fa:16:3f:fe:49:e9,resubmit(,2)
 cookie=0x0, duration=64082.141s, table=1, n_packets=2, n_bytes=200, idle_age=64081, priority=1,dl_vlan=2,dl_src=fa:16:3e:69:b4:05 actions=mod_dl_src:fa:16:3f:fe:49:e9,resubmit(,2)
 cookie=0x0, duration=66135.962s, table=1, n_packets=1, n_bytes=98, idle_age=65301, hard_age=65534, priority=2,dl_vlan=1,dl_dst=fa:16:3e:66:13:af actions=drop 
 cookie=0x0, duration=64082.297s, table=1, n_packets=0, n_bytes=0, idle_age=64082, priority=2,dl_vlan=2,dl_dst=fa:16:3e:69:b4:05 actions=drop
 cookie=0x0, duration=66136.115s, table=1, n_packets=4, n_bytes=168, idle_age=65534, hard_age=65534, priority=3,arp,dl_vlan=1,arp_tpa=10.0.1.1 actions=drop
 cookie=0x0, duration=64082.449s, table=1, n_packets=2, n_bytes=84, idle_age=63991, priority=3,arp,dl_vlan=2,arp_tpa=10.0.2.1 actions=drop
 cookie=0x0, duration=67599.22s, table=1, n_packets=123, n_bytes=10687, idle_age=1741, hard_age=65534, priority=0 actions=resubmit(,2)

这个全局唯一和计算节点绑定的MAC地址，是由neutron全局分配的，数据库中可以看到这个MAC是每个host一个：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/mac1.png "")


它的base MAC是可以在neutron.conf中配置的：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/mac2.png "")

继续查询流表2，表2是VXLAN表，如果是广播包就会查询表22，如果是单播包就查询表20：
 cookie=0x0, duration=67601.554s, table=2, n_packets=176, n_bytes=16981, idle_age=20810, hard_age=65534, priority=0,dl_dst=00:00:00:00:00:00/01:00:00:00:00:00 actions=resubmit(,20)
 cookie=0x0, duration=67601.406s, table=2, n_packets=92, n_bytes=7876, idle_age=1741, hard_age=65534, priority=0,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00 actions=resubmit(,22)

ICMP包是单播包，因此会查询表20，由于开启了L2 pop功能，在表20中会事先学习到应该转发到哪个VTEP。
 cookie=0x0, duration=64076.431s, table=20, n_packets=0, n_bytes=0, idle_age=64076, priority=2,dl_vlan=2,dl_dst=fa:16:3e:13:55:66 actions=strip_vlan,set_tunnel:0x3eb,output:3
 cookie=0x0, duration=66130.899s, table=20, n_packets=152, n_bytes=14728, idle_age=65534, hard_age=65534, priority=2,dl_vlan=1,dl_dst=fa:16:3e:9f:55:67 actions=strip_vlan,set_tunnel:0x3e9,output:3
 cookie=0x0, duration=66560.59s, table=20, n_packets=7, n_bytes=552, idle_age=65534, hard_age=65534, priority=2,dl_vlan=1,dl_dst=fa:16:3e:da:e3:6e actions=strip_vlan,set_tunnel:0x3e9,output:2
 cookie=0x0, duration=64436.717s, table=20, n_packets=0, n_bytes=0, idle_age=64436, priority=2,dl_vlan=1,dl_dst=fa:16:3e:14:b8:ec actions=strip_vlan,set_tunnel:0x3e9,output:4
 cookie=0x0, duration=64015.308s, table=20, n_packets=0, n_bytes=0, idle_age=64015, priority=2,dl_vlan=2,dl_dst=fa:16:3e:51:99:b8 actions=strip_vlan,set_tunnel:0x3eb,output:4
 cookie=0x0, duration=64032.699s, table=20, n_packets=9, n_bytes=917, idle_age=20810, priority=2,dl_vlan=2,dl_dst=fa:16:3e:bb:cf:66 actions=strip_vlan,set_tunnel:0x3eb,output:3
 cookie=0x0, duration=67600.802s, table=20, n_packets=8, n_bytes=784, idle_age=65534, hard_age=65534, priority=0 actions=resubmit(,22)

注：
由于L2 POP并不是本文的重点。因此不在此细说。如果有兴趣可以看以下blog:
http://assafmuller.com/category/overlays/


此时包会变成如下形式：
Dest IP: 10.0.2.5
Souce IP: 10.0.1.5
Dest MAC: MAC of 10.0.2.5
Source MAC: fa:16:3f:fe:49:e9

之后包会从port 4发出：
root@dvr-compute1:~# ovs-vsctl show 
67f121bd-cca7-41c2-95ab-23ed85d1305b
    Bridge br-tun
        Port patch-int
            Interface patch-int
                type: patch
                options: {peer=patch-tun}
        Port "vxlan-0ae09f91"
            Interface "vxlan-0ae09f91"
                type: vxlan
                options: {df_default="true", in_key=flow, local_ip="10.224.159.141", out_key=flow, remote_ip="10.224.159.145"}
        Port "vxlan-0ae09f88"
            Interface "vxlan-0ae09f88"
                type: vxlan
                options: {df_default="true", in_key=flow, local_ip="10.224.159.141", out_key=flow, remote_ip="10.224.159.136"}
        Port br-tun
            Interface br-tun
                type: internal



OVS会将此包进行VXLAN封装，将L2帧分装到VXLAN中，包头如下：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/vlan.png "")


OVS会将此包进行VXLAN封装，将L2帧分装到VXLAN中，包头如下：
本文并不想具体讨论VXLAN是如何封装的，简单的说就是讲二层帧封到了一个UDP包中。



之后compute2会收到这个包，在compute2的br-tun上查询流表:
首先看一下接口情况：
root@dvr-compute2:~# ovs-ofctl show br-tun
OFPT_FEATURES_REPLY (xid=0x2): dpid:000062e9fb8b8f42
n_tables:254, n_buffers:256
capabilities: FLOW_STATS TABLE_STATS PORT_STATS QUEUE_STATS ARP_MATCH_IP
actions: OUTPUT SET_VLAN_VID SET_VLAN_PCP STRIP_VLAN SET_DL_SRC SET_DL_DST SET_NW_SRC SET_NW_DST SET_NW_TOS SET_TP_SRC SET_TP_DST ENQUEUE
 1(patch-int): addr:02:dc:f1:96:db:bd
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 3(vxlan-0ae09f88): addr:b6:4b:d0:83:07:52
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 4(vxlan-0ae09f8d): addr:12:e5:36:2c:1a:36
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 LOCAL(br-tun): addr:62:e9:fb:8b:8f:42
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
OFPT_GET_CONFIG_REPLY (xid=0x4): frags=normal miss_send_len=0


在table0中可以看到，如果包是从外部发来的就会去查询表4：
 cookie=0x0, duration=66293.658s, table=0, n_packets=31, n_bytes=3936, idle_age=22651, hard_age=65534, priority=1,in_port=3 actions=resubmit(,4)
 cookie=0x0, duration=69453.368s, table=0, n_packets=103, n_bytes=9360, idle_age=22651, hard_age=65534, priority=1,in_port=1 actions=resubmit(,1)
 cookie=0x0, duration=66292.808s, table=0, n_packets=20, n_bytes=1742, idle_age=3598, hard_age=65534, priority=1,in_port=4 actions=resubmit(,4)
 cookie=0x0, duration=69455.675s, table=0, n_packets=5, n_bytes=390, idle_age=65534, hard_age=65534, priority=0 actions=drop


在表4中，会将tun_id对应的改为本地vlan id，之后查询表9:
 cookie=0x0, duration=65937.871s, table=4, n_packets=32, n_bytes=3653, idle_age=22651, hard_age=65534, priority=1,tun_id=0x3eb actions=mod_vlan_vid:3,resubmit(,9)
 cookie=0x0, duration=66294.732s, table=4, n_packets=19, n_bytes=2025, idle_age=3598, hard_age=65534, priority=1,tun_id=0x3e9 actions=mod_vlan_vid:2,resubmit(,9)
 cookie=0x0, duration=69455.115s, table=4, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=0 actions=drop


在表9中，如果发现包的源地址是全局唯一并与计算节点绑定的MAC地址，就将其转发到br-int:
 cookie=0x0, duration=69453.507s, table=9, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=1,dl_src=fa:16:3f:fe:49:e9 actions=output:1
 cookie=0x0, duration=69453.782s, table=9, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=1,dl_src=fa:16:3f:72:3f:a7 actions=output:1
 cookie=0x0, duration=69453.23s, table=9, n_packets=56, n_bytes=6028, idle_age=3598, hard_age=65534, priority=0 actions=resubmit(,10)


由于我们的源MAC为fa:16:3f:fe:49:e9，我们的ICMP包就被转发到了br-int，之后查询br-int的流表：
在表0中，如果是全局唯一并与计算节点绑定的MAC地址就查询表1，否则就正常转发：
 cookie=0x0, duration=70039.903s, table=0, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=2,in_port=6,dl_src=fa:16:3f:72:3f:a7 actions=resubmit(,1)
 cookie=0x0, duration=70039.627s, table=0, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=2,in_port=6,dl_src=fa:16:3f:fe:49:e9 actions=resubmit(,1)
 cookie=0x0, duration=70040.053s, table=0, n_packets=166, n_bytes=15954, idle_age=4184, hard_age=65534, priority=1 actions=NORMAL


在表1中，事先设定好了flow，如果目的MAC是发送给private2-compute2-VM，就将源MAC改为private2的网关MAC地址：
 cookie=0x0, duration=66458.695s, table=1, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=4,dl_vlan=3,dl_dst=fa:16:3e:51:99:b8 actions=strip_vlan,mod_dl_src:fa:16:3e:69:b4:05,output:12
 cookie=0x0, duration=66877.515s, table=1, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=4,dl_vlan=2,dl_dst=fa:16:3e:14:b8:ec actions=strip_vlan,mod_dl_src:fa:16:3e:66:13:af,output:9
 cookie=0x0, duration=66877.369s, table=1, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=2,ip,dl_vlan=2,nw_dst=10.0.1.0/24 actions=strip_vlan,mod_dl_src:fa:16:3e:66:13:af,output:9
 cookie=0x0, duration=66458.559s, table=1, n_packets=0, n_bytes=0, idle_age=65534, hard_age=65534, priority=2,ip,dl_vlan=3,nw_dst=10.0.2.0/24 actions=strip_vlan,mod_dl_src:fa:16:3e:69:b4:05,output:12

还可以看到下面两条rule是网段flow的rule，他们的output是一个list，会将此包转发到所有连接到此network上。
如果所有的虚机的rule都已经事先设定好的话，这两条rule应该并没有实际作用，等到代码稳定后，这两条rule应该会被删除。

经过br-int的流表后，包会变成如下形式：
Dest IP: 10.0.2.5
Souce IP: 10.0.1.5
Dest MAC: MAC of 10.0.2.5
Source MAC: fa:16:3e:69:b4:05(MAC of 10.0.2.1 网关地址)

至此，虚机private2-compute2-VM就会收到来自private1-compute1-VM的包了。从通信的过程可以看到，跨网段的东西向流量没有经过网络节点。




第二种情况 -- 南北向流量(虚机有floating ip)
以虚机private1-compute1-VM对外通信为例，此虚机拥有floating ip:


![](https://github.com/chendave/chendave.github.io/raw/master/css/images/interface-last.png "")

比如我们在虚机中ping 8.8.8.8 。首先在虚机中查询路由，和第一种情况一样，虚机会发送给网关。发送的包如下：
Dest IP: 8.8.8.8
Souce IP: 10.0.1.5
Dest MAC: MAC of 10.0.1.1
Source MAC: MAC of 10.0.1.5

查看ip rule:
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip rule 
0: from all lookup local 
32766: from all lookup main 
32767: from all lookup default 
32768: from 10.0.1.5 lookup 16 
32769: from 10.0.2.3 lookup 16 
167772417: from 10.0.1.1/24 lookup 167772417 
167772417: from 10.0.1.1/24 lookup 167772417 
167772673: from 10.0.2.1/24 lookup 167772673

在main表中没有合适的路由：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip route list table main 
10.0.1.0/24 dev qr-ddbdc784-d7 proto kernel scope link src 10.0.1.1 
10.0.2.0/24 dev qr-001d0ed9-01 proto kernel scope link src 10.0.2.1 
169.254.31.28/31 dev rfp-0fbb351e-a proto kernel scope link src 169.254.31.28


由于包是从10.0.1.5发来的之后会查看table 16:
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip route list table 16 
default via 169.254.31.29 dev rfp-0fbb351e-a
包会命中这条路由。

路由之后会通过netfilter的POSTROUTING链中进行SNAT：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa iptables -nvL -t nat
。。。
Chain neutron-l3-agent-float-snat (1 references)
 pkts bytes target prot opt in out source destination
    0 0 SNAT all -- * * 10.0.2.3 0.0.0.0/0 to:172.24.4.7
    0 0 SNAT all -- * * 10.0.1.5 0.0.0.0/0 to:172.24.4.5
。。。

之后就可以看到包会通过rfp-0fbb351e-a发送给169.254.31.29。

端口rfp-0fbb351e-a和fpr-0fbb351e-a是一对veth pair。在fip namespace中你可以看到这个接口：
root@dvr-compute1:~# ip netns exec fip-fbd46644-c70f-4227-a414-862a00cbd1d2 ifconfig
fg-081d537b-06 Link encap:Ethernet  HWaddr fa:16:3e:a4:eb:6b  
          inet addr:172.24.4.6  Bcast:172.24.4.255  Mask:255.255.255.0
          inet6 addr: fe80::f816:3eff:fea4:eb6b/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:50 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:0 (0.0 B)  TX bytes:2512 (2.5 KB)


fpr-0fbb351e-a Link encap:Ethernet  HWaddr 42:0d:9f:49:63:c6  
          inet addr:169.254.31.29  Bcast:0.0.0.0  Mask:255.255.255.254
          inet6 addr: fe80::400d:9fff:fe49:63c6/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:12 errors:0 dropped:0 overruns:0 frame:0
          TX packets:12 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:1116 (1.1 KB)  TX bytes:1116 (1.1 KB)


lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:13 errors:0 dropped:0 overruns:0 frame:0
          TX packets:13 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:1250 (1.2 KB)  TX bytes:1250 (1.2 KB)

到了fip的namespace之后，会查询路由， 这里有通往公网的默认路由：
root@dvr-compute1:~# ip netns exec fip-fbd46644-c70f-4227-a414-862a00cbd1d2 ip route 
default via 172.24.4.1 dev fg-081d537b-06 
169.254.31.28/31 dev fpr-0fbb351e-a proto kernel scope link src 169.254.31.29 
172.24.4.0/24 dev fg-081d537b-06 proto kernel scope link src 172.24.4.6 
172.24.4.5 via 169.254.31.28 dev fpr-0fbb351e-a 
172.24.4.7 via 169.254.31.28 dev fpr-0fbb351e-a

通过fg-081d537b-06 发送到br-ex。这是从虚机发送到公网的过程。


反过来，从外网发起连接到虚机时，在fip的namespace会做arp代理：
root@dvr-compute1:~# ip netns exec fip-fbd46644-c70f-4227-a414-862a00cbd1d2 sysctl net.ipv4.conf.fg-081d537b-06.proxy_arp 
net.ipv4.conf.fg-081d537b-06.proxy_arp = 1

可以看到接口的arp代理是打开的，对于floating ip 有以下两条路由：
root@dvr-compute1:~# ip netns exec fip-fbd46644-c70f-4227-a414-862a00cbd1d2 ip route 
。。。
172.24.4.5 via 169.254.31.28 dev fpr-0fbb351e-a 
172.24.4.7 via 169.254.31.28 dev fpr-0fbb351e-a
。。。


ARP会去通过VETH Pair到IR的namespace中去查询，在IR中可以看到，接口rfp-0fbb351e-a配置了floating ip:
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: rfp-0fbb351e-a: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether ea:5c:56:9a:36:9c brd ff:ff:ff:ff:ff:ff
    inet 169.254.31.28/31 scope global rfp-0fbb351e-a
       valid_lft forever preferred_lft forever
    inet 172.24.4.5/32 brd 172.24.4.5 scope global rfp-0fbb351e-a
       valid_lft forever preferred_lft forever
    inet 172.24.4.7/32 brd 172.24.4.7 scope global rfp-0fbb351e-a
       valid_lft forever preferred_lft forever
    inet6 fe80::e85c:56ff:fe9a:369c/64 scope link 
       valid_lft forever preferred_lft forever
17: qr-ddbdc784-d7: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
    link/ether fa:16:3e:66:13:af brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.1/24 brd 10.0.1.255 scope global qr-ddbdc784-d7
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe66:13af/64 scope link 
       valid_lft forever preferred_lft forever
19: qr-001d0ed9-01: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
    link/ether fa:16:3e:69:b4:05 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.1/24 brd 10.0.2.255 scope global qr-001d0ed9-01
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe69:b405/64 scope link 
       valid_lft forever preferred_lft forever


因此fip的namespace会对这两个floating ip进行ARP回应。

外部发起目标地址为floating ip的请求后，fip会将其转发到IR中，IR的RPOROUTING链中规则如下：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa iptables -nvL -t nat
。。。
Chain neutron-l3-agent-PREROUTING (1 references)
 pkts bytes target prot opt in out source destination
    0 0 REDIRECT tcp -- * * 0.0.0.0/0 169.254.169.254 tcp dpt:80 redir ports 9697
    0 0 DNAT all -- * * 0.0.0.0/0 172.24.4.7 to:10.0.2.3
    0 0 DNAT all -- * * 0.0.0.0/0 172.24.4.5 to:10.0.1.5
。。。

这条DNAT规则会将floating ip地址转换为内部地址，之后进行路由查询：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip route 
10.0.1.0/24 dev qr-ddbdc784-d7 proto kernel scope link src 10.0.1.1 
10.0.2.0/24 dev qr-001d0ed9-01 proto kernel scope link src 10.0.2.1 
169.254.31.28/31 dev rfp-0fbb351e-a proto kernel scope link src 169.254.31.28

目的地址是10.0.1.0/24网段的，因此会从qr-ddbdc784-d7转发出去。之后就会转发到br-int再到虚机。




第三种情况 -- 南北向流量(虚机没有floating ip)
在虚机没有floating ip的情况下，从虚机发出的包会首先到IR，IR中查询路由：
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip rule 
0: from all lookup local 
32766: from all lookup main 
32767: from all lookup default 
32768: from 10.0.1.5 lookup 16 
32769: from 10.0.2.3 lookup 16 
167772417: from 10.0.1.1/24 lookup 167772417 
167772417: from 10.0.1.1/24 lookup 167772417 
167772673: from 10.0.2.1/24 lookup 167772673

会先查询main表，之后查询167772417表。
root@dvr-compute1:~# ip netns exec qrouter-0fbb351e-a65b-4790-a409-8fb219ce16aa ip route list table 167772417 
default via 10.0.1.6 dev qr-ddbdc784-d7

这个表会将其转发给10.0.1.6,而这个IP就是在network node上的router_centralized_snat接口。

在network node的snat namespace中，我们可以看到这个接口：
stack@dvr-controller:/root$ sudo ip netns exec snat-0fbb351e-a65b-4790-a409-8fb219ce16aa ifconfig
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)


qg-4d15b7f6-cb Link encap:Ethernet  HWaddr fa:16:3e:24:0b:6b  
          inet addr:172.24.4.4  Bcast:172.24.4.255  Mask:255.255.255.0
          inet6 addr: fe80::f816:3eff:fe24:b6b/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:5 errors:0 dropped:0 overruns:0 frame:0
          TX packets:144 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:210 (210.0 B)  TX bytes:13320 (13.3 KB)


sg-427653e4-a3 Link encap:Ethernet  HWaddr fa:16:3e:9f:55:67  
          inet addr:10.0.1.6  Bcast:10.0.1.255  Mask:255.255.255.0
          inet6 addr: fe80::f816:3eff:fe9f:5567/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:167 errors:0 dropped:0 overruns:0 frame:0
          TX packets:52 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:16260 (16.2 KB)  TX bytes:4460 (4.4 KB)


sg-5df1ec71-d3 Link encap:Ethernet  HWaddr fa:16:3e:13:55:66  
          inet addr:10.0.2.2  Bcast:10.0.2.255  Mask:255.255.255.0
          inet6 addr: fe80::f816:3eff:fe13:5566/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:34 errors:0 dropped:0 overruns:0 frame:0
          TX packets:12 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:3412 (3.4 KB)  TX bytes:952 (952.0 B)




stack@dvr-controller:/root$ sudo ip netns exec snat-0fbb351e-a65b-4790-a409-8fb219ce16aa iptables -nvL -t nat
。。。
Chain neutron-l3-agent-snat (1 references)
 pkts bytes target prot opt in out source destination
    0 0 SNAT all -- * * 10.0.1.0/24 0.0.0.0/0 to:172.24.4.4
    0 0 SNAT all -- * * 10.0.2.0/24 0.0.0.0/0 to:172.24.4.4
。。。


这里就和以前的L3类似，会将没有floating ip的包SNAT成一个172.24.4.4(DVR的网关臂)。这个过程是和以前L3类似的，不再累述。




stack@dvr-controller:/root$ sudo ip netns exec snat-0fbb351e-a65b-4790-a409-8fb219ce16aa iptables -nvL -t nat
。。。
Chain neutron-l3-agent-snat (1 references)
 pkts bytes target prot opt in out source destination
    0 0 SNAT all -- * * 10.0.1.0/24 0.0.0.0/0 to:172.24.4.4
    0 0 SNAT all -- * * 10.0.2.0/24 0.0.0.0/0 to:172.24.4.4
。。。


这里就和以前的L3类似，会将没有floating ip的包SNAT成一个172.24.4.4(DVR的网关臂)。这个过程是和以前L3类似的，不再累述。

--------------------- 

原文：https://blog.csdn.net/matt_mao/article/details/39180135 



