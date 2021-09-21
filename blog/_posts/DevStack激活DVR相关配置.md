---
title: DevStack激活DVR相关配置
date: 2018-08-11 16:57:25
thumbnail: /css/images/芦荟.png
tags: OpenStack
---

这些日子脑子里经常会想到《可可西里》电影里的一个画面，从刚陷入到流沙时的垂死挣扎越陷越深到后来彻底绝望放弃，电影表达了个人在恶劣的自然环境下的无能无力，换个角度想想，我们绝大多数人何尝不是已经陷入了深不见底的绝望之中，只不过这里不是沙漠戈壁而是同样现实的社会，我们挣扎着，不想认命，不想就此结束，但是结果常常是在岁月的流逝中，一步步走向属于我们这代人的结局。

DVR(Distributed virtual router)已经理解的差不多了，一句话来总结DVR就是DVR可以网络流量的负载均衡，以解决过往所有流量需要网络节点参与从而可能造成性能瓶颈的问题。这里分享一下如何在DevStack中做配置来激活DVR，

- controller节点(网络节点)
``` bash
## Base configuration
HOST_IP=192.168.20.132
SERVICE_HOST=192.168.20.132
MYSQL_HOST=$SERVICE_HOST
RABBIT_HOST=$SERVICE_HOST
GLANCE_HOSTPORT=$SERVICE_HOST:9292
ADMIN_PASSWORD=abc123
DATABASE_PASSWORD=abc123
RABBIT_PASSWORD=abc123
SERVICE_PASSWORD=abc123
DATABASE_TYPE=mysql

# Neutron options
Q_USE_SECGROUP=True
FLOATING_RANGE="192.168.23.1/21"
Q_FLOATING_ALLOCATION_POOL=start=192.168.23.120,end=192.168.23.150
IPV4_ADDRS_SAFE_TO_USE="10.0.0.0/22"
PUBLIC_NETWORK_GATEWAY="192.168.18.1"
PUBLIC_INTERFACE=eno1

# Open vSwitch provider networking configuration
Q_USE_PROVIDERNET_FOR_PUBLIC=True
OVS_PHYSICAL_BRIDGE=br-ex
PUBLIC_BRIDGE=br-ex
OVS_BRIDGE_MAPPINGS=public:br-ex

# Multi-node cluster
MULTI_HOST=1

# MISC
LOGFILE=/opt/stack/logs/stack.sh.log
NOVA_VNC_ENABLED=True
NOVNCPROXY_URL="http://$SERVICE_HOST:6080/vnc_auto.html"
VNCSERVER_LISTEN=$HOST_IP
VNCSERVER_PROXYCLIENT_ADDRESS=$VNCSERVER_LISTEN
GIT_BASE=https://git.openstack.org

# Settings for DVR networking, DVR depends on vxlan and ml2/ovs,
# this is not verified in the latest version.
# The setting on the network node.
Q_DVR_MODE=dvr_snat
Q_PLUGIN=ml2
Q_ML2_TENANT_NETWORK_TYPE=vxlan

```


- 计算节点（这里需要注意**ENABLED_SERVICES**中需要将neutron相关的服务都加上，DHCP服务除外）

``` bash
# Basic configuration
# Reference: https://docs.openstack.org/devstack/latest/guides/neutron.html
HOST_IP=192.168.18.79
SERVICE_HOST=192.168.20.132
MYSQL_HOST=$SERVICE_HOST
RABBIT_HOST=$SERVICE_HOST
GLANCE_HOSTPORT=$SERVICE_HOST:9292
ADMIN_PASSWORD=abc123
DATABASE_PASSWORD=abc123
MYSQL_PASSWORD=abc123
RABBIT_PASSWORD=abc123
SERVICE_PASSWORD=abc123
DATABASE_TYPE=mysql
MULTI_HOST=1

# Neutron options
FLOATING_RANGE="192.168.23.1/21"
Q_FLOATING_ALLOCATION_POOL=start=192.168.23.120,end=192.168.23.150
IPV4_ADDRS_SAFE_TO_USE="10.0.0.0/22"
PUBLIC_NETWORK_GATEWAY="192.168.18.1"
PUBLIC_INTERFACE=eno1

# Services that a compute node runs
ENABLED_SERVICES=n-cpu,q-agt,n-api-meta,c-vol,placement-client,placement-api,neutron,q-l3,q-meta

# Misc configuration
LOGFILE=/opt/stack/logs/stack.sh.log
NOVA_VNC_ENABLED=True
NOVNCPROXY_URL="http://$SERVICE_HOST:6080/vnc_auto.html"
VNCSERVER_LISTEN=$HOST_IP
VNCSERVER_PROXYCLIENT_ADDRESS=$VNCSERVER_LISTEN
GIT_BASE=https://git.openstack.org

# Settings for DVR networking
Q_DVR_MODE=dvr
Q_PLUGIN=ml2
Q_ML2_TENANT_NETWORK_TYPE=vxlan
```

这里或许有部分参数是可选的，但是加上也没有关系。

---
[1] https://github.com/chendave/initrepo/tree/master/openstack/localrc/dvr
