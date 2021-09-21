---
title: 我的数据在哪儿? - Ceph rbd image
date: 2018-04-21 13:06:14
thumbnail: /css/images/sunshine.jpg
tags: Ceph
---

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/sunshine.jpg "")

Ceph的rbd image可以用来作为OpenStack的块存储，如果OpenStack配置Cinder存储后端为Ceph，实际上读写的就是Ceph的块存储设备，这里记录如何查看rbd image里的数据，以及数据存放在哪里。


首先来创建一个rbd image

``` bash
ceph osd pool create rbdbench 100 100  #创建一个名为rbdbench的pool，pg与pgp size均为100

rbd create image01 --size 1024 --pool rbdbench --image-format 2  # format 1已经deprecated了，format 2 包含了更多的特性。
```

这里不需要做rbd的mapping操作，也无需mount rbd image，我们只想来看看rbd image里文件存放位置，如果需要做mapping，则需要修改ceph的主配置文件来忽略系统不支持的一些ceph的特性。

```bash
sed -i '$a\rbd_default_features = 3' /etc/ceph/ceph.conf
```

接下来，我们通过rbd info查看image的一些详细信息：
```bash
$ rbd -p rbdbench info image01
rbd image 'image01':
        size 1024 MB in 256 objects
        order 22 (4096 kB objects)
        block_name_prefix: rbd_data.4dde74b0dc51
        format: 2
        features: layering
        flags:
```
块设备里已经有256个object了，这些个object是什么，我们以后再看，通过block_name_prefix来查看pool里的objects.
```bash
$ rados -p rbdbench ls | grep ^rbd_data.4dde74b0dc51
rbd_data.4dde74b0dc51.0000000000000060
rbd_data.4dde74b0dc51.0000000000000086
rbd_data.4dde74b0dc51.0000000000000084
rbd_data.4dde74b0dc51.0000000000000081
rbd_data.4dde74b0dc51.00000000000000e0
rbd_data.4dde74b0dc51.0000000000000083
rbd_data.4dde74b0dc51.0000000000000000
rbd_data.4dde74b0dc51.00000000000000a0
rbd_data.4dde74b0dc51.0000000000000080
rbd_data.4dde74b0dc51.0000000000000004
rbd_data.4dde74b0dc51.0000000000000082
rbd_data.4dde74b0dc51.0000000000000085
rbd_data.4dde74b0dc51.00000000000000ff
rbd_data.4dde74b0dc51.0000000000000087
rbd_data.4dde74b0dc51.0000000000000020
```
接下来就可以通过下面的命令来查找object所在的pg以及相应的OSD了。例如：

```bash
$ ceph osd map rbdbench rbd_data.4dde74b0dc51.0000000000000086
osdmap e505 pool 'rbdbench' (16) object 'rbd_data.4dde74b0dc51.0000000000000086' -> pg 16.eabd8f8a (16.a) -> up ([2,1], p2) acting ([2,1], p2)
```

```bash
$ ceph osd tree
ID WEIGHT  TYPE NAME      UP/DOWN REWEIGHT PRIMARY-AFFINITY
-1 5.44080 root default
-2 1.81360     host ceph3
 2 1.81360         osd.2       up  1.00000          1.00000
-3       0     host ceph4
-4 3.62720     host ceph1
 0 1.81360         osd.0       up  1.00000          1.00000
 1 1.81360         osd.1       up  1.00000          1.00000
```

数据所在的主OSD为2， 从OSD为1， pg号为“16.a”，这样登录到OSD所在的机器，就可以查看到object的data文件了。

```bash
root@ceph3:/var/lib/ceph/osd/ceph-2/current/16.a_head# file rbd\\udata.4dde74b0dc51.0000000000000086__head_EABD8F8A__10
rbd\udata.4dde74b0dc51.0000000000000086__head_EABD8F8A__10: data
```

有几个问题，rbd初始创建的object到底是什么？除了“block_name_prefix”指定的object之外，还有哪些objects? 可否通过这种方式创建一个image，然后写入一个文件，再去查看文件的存储位置，以及完整性校验等。

