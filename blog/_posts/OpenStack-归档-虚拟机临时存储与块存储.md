---
title: OpenStack 归档 - 虚拟机临时存储与块存储
date: 2018-11-04 15:06:04
tags: OpenStack
thumbnail: /css/images/birthday.png
---

总体来说，虚拟机内部的存储分临时存储与可拔插的块存储两部分，所谓临时存储既是指存储空间会随着虚拟机的创建而产生，删除而消亡。而块存储(volume)则可以将用户的数据保存下来，并可以attach到不通的虚机机上。

## 默认情况

默认情况创建一个虚机只有一个盘，mount到root分区，看下下面的例子。

``` bash
nova boot default --image cirros-0.3.5-x86_64-disk --flavor m1.small --nic net-name=private
```

``` bash
$ sudo fdisk -l

Disk /dev/vda: 21.5 GB, 21474836480 bytes
255 heads, 63 sectors/track, 2610 cylinders, total 41943040 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x00000000

   Device Boot      Start         End      Blocks   Id  System
/dev/vda1   *       16065    41929649    20956792+  83  Linux
$ df -h
Filesystem                Size      Used Available Use% Mounted on
/dev                    998.3M         0    998.3M   0% /dev
/dev/vda1                23.2M     18.0M      4.0M  82% /
tmpfs                  1001.8M         0   1001.8M   0% /dev/shm
tmpfs                   200.0K     68.0K    132.0K  34% /run
```

``` bash
$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
vda    253:0    0  20G  0 disk
`-vda1 253:1    0  20G  0 part /
```

## 块设备
如果希望数据能持久的保存下来，即便虚拟机被删之后，还能找到在之前的数据，可以给虚拟机添加一个块设备。块设备由*Cinder*服务提供，可以将其理解为一块U盘，可以动态的拔插到的你的电脑上。如下，我们给虚拟机添加一个块设备*volume*。

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/attach_volume.png "")

再来看看虚拟机里的存储空间，我们会发现多出来一块盘。

```
$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
vda    253:0    0  20G  0 disk
`-vda1 253:1    0  20G  0 part /
vdb    253:16   0   1G  0 disk


$ sudo fdisk -l

Disk /dev/vda: 21.5 GB, 21474836480 bytes
255 heads, 63 sectors/track, 2610 cylinders, total 41943040 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x00000000

   Device Boot      Start         End      Blocks   Id  System
/dev/vda1   *       16065    41929649    20956792+  83  Linux

Disk /dev/vdb: 1073 MB, 1073741824 bytes
16 heads, 63 sectors/track, 2080 cylinders, total 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x00000000
```


## Ephemeral 与Swap 

另外，可以根据需要在虚拟机里创建一些临时的分区/盘，但这些盘同样会时随着虚拟机的生命周期消亡而消亡。
首先创建一个flavor,

``` bash 
$ nova flavor-create --ephemeral 20 --swap 512 testeph 7 512 1 1
+----+---------+-----------+------+-----------+------+-------+-------------+-----------+
| ID | Name    | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
+----+---------+-----------+------+-----------+------+-------+-------------+-----------+
| 7  | testeph | 512       | 1    | 20        | 512  | 1     | 1.0         | True      |
+----+---------+-----------+------+-----------+------+-------+-------------+-----------+
```

根据此flavor创建一个虚拟机:

```
$ nova boot --image cirros-0.3.5-x86_64-disk --flavor 7 --nic net-name=private --ephemeral size=1 emph1 

$ sudo fdisk -l
	
Disk /dev/vda: 1073 MB, 1073741824 bytes
255 heads, 63 sectors/track, 130 cylinders, total 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x00000000

Device Boot      Start         End      Blocks   Id  System
/dev/vda1   *       16065     2088449     1036192+  83  Linux

Disk /dev/vdb: 1073 MB, 1073741824 bytes
16 heads, 63 sectors/track, 2080 cylinders, total 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x00000000

Disk /dev/vdb doesn't contain a valid partition table

Disk /dev/vdc: 536 MB, 536870912 bytes
16 heads, 63 sectors/track, 1040 cylinders, total 1048576 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x00000000

$ lsblk
NAME   MAJ:MIN RM    SIZE RO TYPE MOUNTPOINT
vda    253:0    0      1G  0 disk
`-vda1 253:1    0 1011.9M  0 part /
vdb    253:16   0      1G  0 disk /mnt
vdc    253:32   0    512M  0 disk
```

可以看出，swap和ephemeral 是以独立的虚拟磁盘来呈现的。*disk.eph0* 与 *disk.swap* 都存放在虚拟机的目录下，这意味着虚拟机删除之后，这些文件也将随之被删除。

``` bash
$ ls /opt/stack/data/nova/instances/29cc9a74-bebc-429d-a0b8-58fbfe89b2cd
console.log  disk  disk.eph0  disk.info  disk.swap
```
