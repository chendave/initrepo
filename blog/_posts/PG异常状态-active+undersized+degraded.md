---
title: PG 异常状态- active+undersized+degraded
date: 2018-06-23 16:53:31
thumbnail: /css/images/baby1.jpg
tags: Ceph
---

自己搭的3个OSD节点的集群的健康状态经常处在"WARN"状态，replicas设置为3，OSD节点数量大于3，存放的data数量也不多，**ceph -s** 不是期待的health ok，而是**active+undersized+degraded**。被这个问题困扰有段时间，因为对Ceph不太了解而一直没有找到解决方案，直到最近发邮件到社区才得到解决[1]。

### PG状态的含义
PG的非正常状态说明可以参考[2]，**undersized**与**degraded**的含义记录于此：
> undersized
> The placement group has fewer copies than the configured pool replication level.
> degraded
> Ceph has not replicated some objects in the placement group the correct number of times yet.
这两种状态一般同时出现，大概的意思就是有些PG没有满足设定的replicas数量要求，PG中的部分objects亦如此。看下PG的详细信息：

``` bash
ceph health detail
HEALTH_WARN 2 pgs degraded; 2 pgs stuck degraded; 2 pgs stuck unclean; 2 pgs 
stuck undersized; 2 pgs undersized
pg 17.58 is stuck unclean for 61033.947719, current state 
active+undersized+degraded, last acting [2,0]
pg 17.16 is stuck unclean for 61033.948201, current state 
active+undersized+degraded, last acting [0,2]
pg 17.58 is stuck undersized for 61033.343824, current state 
active+undersized+degraded, last acting [2,0]
pg 17.16 is stuck undersized for 61033.327566, current state 
active+undersized+degraded, last acting [0,2]
pg 17.58 is stuck degraded for 61033.343835, current state 
active+undersized+degraded, last acting [2,0]
pg 17.16 is stuck degraded for 61033.327576, current state 
active+undersized+degraded, last acting [0,2]
pg 17.16 is active+undersized+degraded, acting [0,2]
pg 17.58 is active+undersized+degraded, acting [2,0]
```

### 解决办法
虽然设定的拷贝数量是3，但是PG 17.58与17.58却只有两个拷贝，分别存放在OSD 0与OSD 2上。
而究其原因则是我们的OSD所在的磁盘不是同质的，从而每个OSD的weight不同，而Ceph对异质OSD的支持不是很好。从而导致部分PG无法满足我们设定的备份数量限制。

OSD状态树：

``` bash
ceph osd tree
ID WEIGHT  TYPE NAME      UP/DOWN REWEIGHT PRIMARY-AFFINITY
-1 5.89049 root default
-2 1.81360     host ceph3
2 1.81360         osd.2       up  1.00000          1.00000
-3 0.44969     host ceph4
3 0.44969         osd.3       up  1.00000          1.00000
-4 3.62720     host ceph1
0 1.81360         osd.0       up  1.00000          1.00000
1 1.81360         osd.1       up  1.00000          1.00000
```

解决办法是另外构建一个OSD，使其容量大小和其它节点相同，是否可以有偏差？猜测应该有一个可以接受的偏差范围，重构后的OSD节点树看起来像这样：

``` bash
$ ceph osd tree
ID WEIGHT  TYPE NAME      UP/DOWN REWEIGHT PRIMARY-AFFINITY
-1 7.25439 root default
-2 1.81360     host ceph3
 2 1.81360         osd.2       up  1.00000          1.00000
-3       0     host ceph4
-4 3.62720     host ceph1
 0 1.81360         osd.0       up  1.00000          1.00000
 1 1.81360         osd.1       up  1.00000          1.00000
-5 1.81360     host ceph2
 3 1.81360         osd.3       up  1.00000          1.00000
```

ceph4节点被删除，重新加入了另一个OSD节点ceph2。

``` bash
$ ceph -s
    cluster 20ab1119-a072-4bdf-9402-9d0ce8c256f4
     health HEALTH_OK
     monmap e2: 2 mons at {ceph2=192.168.17.21:6789/0,ceph4=192.168.17.23:6789/0}
            election epoch 26, quorum 0,1 ceph2,ceph4
     osdmap e599: 4 osds: 4 up, 4 in
            flags sortbitwise,require_jewel_osds
      pgmap v155011: 100 pgs, 1 pools, 18628 bytes data, 1 objects
            1129 MB used, 7427 GB / 7428 GB avail
                 100 active+clean
```

另外，为了满足HA的要求，OSD需要分散在不同的节点上，这里拷贝数量为3，则需要有三个OSD节点来承载这些OSD，如果三个OSD分布在两个OSD节点上，则依然可能会出现"active+undersized+degraded"的状态。

官方是这样说的：

> This, combined with the default CRUSH failure domain, ensures that replicas or erasure code shards are separated across hosts and a single host failure will not affect availability.

理解如有错误还望能点醒。


---
[1] https://www.mail-archive.com/ceph-users@lists.ceph.com/msg47070.html
[2] http://docs.ceph.com/docs/master/rados/operations/pg-states/
