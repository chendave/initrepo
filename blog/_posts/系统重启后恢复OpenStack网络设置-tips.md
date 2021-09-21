---
title: 系统重启后恢复OpenStack网络设置-tips
date: 2018-09-24 17:22:59
tags: OpenStack
thumbnail: /css/images/莫干山.jpg
---

眼看着今天就要过去了，一个月就要过去了，马上一年也就要过去了，可你又能怎样？
昨天在焦虑，今天还在焦虑，明天将继续焦虑，何时能停止？
既然无力挣扎，那就闭着眼睛过吧，时间最终会给我们答案，尘过尘，土归土，看谈一些就好，看空一些就好。

不管OpenStack是不是还有些把玩的价值，但终归割舍不下，我一直把它看作一本书，一本可以提升自己的书，至于它能带给你什么？ Who knows? Who cares?

所以，当实验室里每次断电之后，虚拟网络都将无法工作，我还是会继续去*stack*一下，终于有一天我无法再次忍受，我要去看个究竟，当愚钝的翻过一行一行脚本之后，我好像找到了答案。

先看看*lib/neutron_plugins/services/l3*里的这个函数：

``` bash
function _configure_neutron_l3_agent {

    cp $NEUTRON_DIR/etc/l3_agent.ini.sample $Q_L3_CONF_FILE

    iniset $Q_L3_CONF_FILE DEFAULT debug $ENABLE_DEBUG_LOG_LEVEL
    iniset $Q_L3_CONF_FILE AGENT root_helper "$Q_RR_COMMAND"
    if [[ "$Q_USE_ROOTWRAP_DAEMON" == "True" ]]; then
        iniset $Q_L3_CONF_FILE AGENT root_helper_daemon "$Q_RR_DAEMON_COMMAND"
    fi

    _neutron_setup_interface_driver $Q_L3_CONF_FILE

    neutron_plugin_configure_l3_agent $Q_L3_CONF_FILE

    # If we've given a PUBLIC_INTERFACE to take over, then we assume
    # that we can own the whole thing, and privot it into the OVS
    # bridge. If we are not, we're probably on a single interface
    # machine, and we just setup NAT so that fixed guests can get out.
    if [[ -n "$PUBLIC_INTERFACE" ]]; then   # *看这里!* 
        _move_neutron_addresses_route "$PUBLIC_INTERFACE" "$OVS_PHYSICAL_BRIDGE" True False "inet"

        if [[ $(ip -f inet6 a s dev "$PUBLIC_INTERFACE" | grep -c 'global') != 0 ]]; then
            _move_neutron_addresses_route "$PUBLIC_INTERFACE" "$OVS_PHYSICAL_BRIDGE" False False "inet6"
        fi
    else
        for d in $default_v4_route_devs; do
            sudo iptables -t nat -A POSTROUTING -o $d -s $FLOATING_RANGE -j MASQUERADE
        done
    fi
}
```

从这个函数可以看出，如果绑定了某一个物理网卡（例如在*localrc*中配置了"PUBLIC_INTERFACE"），那么将会调用"_move_neutron_addresses_route"来做进一步处理，否则就做一个源地址伪装（MASQUERADE）就算完了。

核心就是这段代码了，
``` bash
_move_neutron_addresses_route "$PUBLIC_INTERFACE" "$OVS_PHYSICAL_BRIDGE" True False "inet"
```

来重点看下绑定物理网卡的处理方式，函数有点长，我们调重点的看一下部分核心代码，
``` bash
# lib/neutron-legacy
# _move_neutron_addresses_route() - Move the primary IP to the OVS bridge
# on startup, or back to the public interface on cleanup. If no IP is
# configured on the interface, just add it as a port to the OVS bridge.
function _move_neutron_addresses_route {
...
    if [[ -n "$from_intf" && -n "$to_intf" ]]; then
...
        DEFAULT_ROUTE_GW=$(ip -f $af r | awk "/default.+$from_intf\s/ { print \$3; exit }") 
        IP_BRD=$(ip -f $af a s dev $from_intf scope global primary | grep inet | awk '{ print $2, $3, $4; exit }') #①

        if [ "$DEFAULT_ROUTE_GW" != "" ]; then
            ADD_DEFAULT_ROUTE="sudo ip -f $af r replace default via $DEFAULT_ROUTE_GW dev $to_intf" # ②
        fi

        if [[ "$add_ovs_port" == "True" ]]; then
            ADD_OVS_PORT="sudo ovs-vsctl --may-exist add-port $to_intf $from_intf" # ③
        fi
...
        if [[ "$IP_BRD" != "" ]]; then
            IP_DEL="sudo ip addr del $IP_BRD dev $from_intf" # ④
            IP_REPLACE="sudo ip addr replace $IP_BRD dev $to_intf" # ⑤ 
            IP_UP="sudo ip link set $to_intf up" # ⑥
            if [[ "$af" == "inet" ]]; then
                IP=$(echo $IP_BRD | awk '{ print $1; exit }' | grep -o -E '(.*)/' | cut -d "/" -f1)
                ARP_CMD="arping -A -c 3 -w 4.5 -I $to_intf $IP " # ⑦
            fi
        fi
...
        $DEL_OVS_PORT; $IP_DEL; $IP_REPLACE; $IP_UP; $ADD_OVS_PORT; $ADD_DEFAULT_ROUTE; $ARP_CMD

```

先来看下网络的路由配置情况，*eno2*将会作为*PUBLIC_INTERFACE*被绑定到*br-ex*上。

``` bash
$ ip route
default via 192.168.18.1 dev eno2  proto static  metric 100
169.254.0.0/16 dev docker0  scope link  metric 1000 linkdown
172.17.0.0/16 dev docker0  proto kernel  scope link  src 172.17.0.1 linkdown
192.168.16.0/21 dev eno2  proto kernel  scope link  src 192.168.18.24  metric 100
```

1. 这两句是获取系统当前的一些网络配置，*DEFAULT_ROUTE_GW*是物理机的默认路由，*IP_BRD*得到的是物理网卡上的主IP地址配置。
``` bash
$ ip -f inet r | awk "/default.+eno2\s/ { print \$3; exit }"
192.168.18.1

$ ip -f inet a s dev eno2 scope global primary | grep inet | awk '{ print $2, $3, $4; exit }'
192.168.18.24/21 brd 192.168.23.255
```

2. 将默认路由替换为目标网卡，这里当然是替换为OVS的bridge *br-ex*，这一步之后默认的路由的IP地址虽然没变，但是device已经改为*br-ex*了。
``` bash
$ sudo ip -f inet r replace default via 192.168.18.1 dev br-ex
```

3. 将物理网卡绑定到*br-ex*上。
``` bash
$ sudo ovs-vsctl --may-exist add-port br-ex eno2
```

4. 这一步将物理网卡上的主IP地址删除，之后该地址将配置到*br-ex*上。
``` bash
$ sudo ip addr del 192.168.18.24/21 brd 192.168.23.255 dev eno2
```

5. 将物理网卡上的主IP地址配置到*br-ex*上。
``` bash
$ sudo ip addr replace 192.168.18.24/21 brd 192.168.23.255 dev br-ex
```

6. 不解释
``` bash
$ sudo ip link set br-ex up
```

7. 设置ARP请求的一些参数，arping没用过，具体在干什么，还是不太了解。

``` bash
$ arping -A -c 3 -w 4.5 -I br-ex 192.168.18.24
```

之后就是顺序执行这几个命令了，一句话来解释这段代码干的事情就是这段注释:
> Move the primary IP to the OVS bridge on startup, or back to the
> public interface on cleanup. If no IP is configured on the interface,
> just add it as a port to the OVS bridge.

如果系统reboot了，网络挂了，不行就顺序再来一便吧，但问题是为什么网络不能自动恢复？这是个大问题啊？！

希望国庆节之后能对DVR来做个了结吧。

p.s. 天又晚了，码字确实费时间。
