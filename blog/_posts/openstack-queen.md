---
title: OpenStack Queen 版本变更概述
thumbnail: /css/images/openstack.jpg
date: 2018-04-14 15:44:53
tags: OpenStack
---

![](https://raw.githubusercontent.com/chendave/initrepo/master/pic/banner.jpg "")

毫无疑问，OpenStack正在经历它的低谷期，和芸芸众生一样，无法改变世界那就得改变自己来适应这个世界，真心的期待，曾经的王者有朝一日能再现昔日辉煌。

回过头来看Queen版本的一些主要变更，Mirantis的这篇文章[1] 总结的不错，

### 优化 ###
Queen版本之前，使用GPU做科学计算和机器学习，可以通过使用PCI pass through或者直接用Ironic来操作裸机，Queen版本增加了新的flavor，可以像其它flavor例如vCPUs一样来支持对GPU资源作出的请求。

### 高可用性 ###
个人觉得这个特性对OpenStack的落地是个很大的提高，尤其是虚拟机层次的高可用性， 围绕这个特性，块存储以及裸机管理方面的相关功能也都值得期待。


### 边缘计算 ###
围绕边缘计算和容器化，我们可以看到新的项目如LOCI和OpenStack-Helm所作出的努力，OpenStack容器化已经有些年头，而一时间出来这么多和Container相关的项目也算是OpenStack受诟病的一个原因吧，能否多这么的项目做个整合，再比如早起的Kolla?

下个版本据说是要更加关注NFV了，祝OpenStack一路走好吧！

附原文：

OpenStack embraces the future with GPU, edge computing support

It wasn’t that long ago that OpenStack was the hot new kid on the infrastructure block. Lately, though, other technologies have been vying for that spot, making the open source cloud platform look downright stodgy in comparison. That just might change with the latest release of OpenStack, code-named Queens.

The Queens release makes it abundantly clear that the OpenStack community, far from resting on its laurels or burying its collective head in the digital sand, has been paying attention to what’s going on in the cloud space and adjusting its efforts accordingly. Queens includes capabilities that wouldn’t even have been possible when the OpenStack project started, let alone considered, such as GPU support (handy for scientific and machine learning/AI workloads) and a focus on Edge Computing that makes use of the current new kid on the block, Kubernetes.


**Optimization**

While OpenStack users have been able to utilize GPUs for scientific and machine learning purposes for some time, it has typically been through the use of either PCI passthrough or by using Ironic to manage an entire server as a single instance — neither of which was particularly convenient. Queens now makes it possible to provision virtual GPUs (vGPUs) using specific flavors, just as you would provision traditional vCPUs.

Queens also includes the debut of the Cyborg project, which provides a management framework for different types of accelerators such as GPUs, FPGA, NVMe/NOF, SSDs, DPDK, and so on. This capability is important not just for GPU-related use cases, but also for situations such as NFV.


**High Availability**

As OpenStack becomes more of an essential tool and less of a science project, the need for high availability has grown. The OpenStack Queens release addresses this need in several different ways.

The OpenStack Instances High Availability Service, or Masakari, provides an API to manage the automated rescue mechanism that recovers instances that fail because of process down, provisioning process down, or nova-compute host failure events.

While Masakari currently supports KVM-based VMs, Ironic bare metal nodes have always been more difficult to recover. Queens debuts the Ironic Rescue Mode (one of our favorite feature names of all time), which makes it possible to recover an Ironic node that has gone down.

Another way OpenStack Queens provides HA capabilities is through Cinder’s new volume multi-attach feature. The OpenStack Block Storage Service’s new capability makes it possible to attach a single volume to multiple VMs, so if one of those instances fails, traffic can be routed to an identical instance that is using the same storage.


**Edge Computing**

What’s become more than obvious, though, is that OpenStack has realized that the future doesn’t lay in just a few concentrated datacenters, but rather that workloads will be in a variety of diverse locations. Specifically, Edge Computing, in which we will see multiple smaller clouds closer to the user rather than a single centralized cloud, is coming into its own as service providers and others realize its importance.

To that end, OpenStack has been focused on several projects to adapt itself to that kind of environment, including LOCI and OpenStack-Helm.

OpenStack LOCI provides Lightweight OCI compatible images of OpenStack services so that they can be deployed by a container orchestration tool such as Kubernetes. As of the Queens release, images are available for Cinder, Glance, Heat, Horizon, Ironic, Keystone, Neutron and Nova.

And of course since orchestrating a containerized deployment of OpenStack isn’t necessarily any easier than deploying a non-containerized version, there’s OpenStack-Helm, a collection of Helm charts that install the various OpenStack services on a Kubernetes cluster.


**Other container-related advances**

If it seems like there’s a focus on integrating with container-based services, you’re right. Another way OpenStack has integrated with Kubernetes is through the Kuryr CNI plugin. The Container Network Interface (CNI) is a CNCF project that standardizes container networking operations, and the Kuryr CNI plugin makes it possible to use OpenStack Neutron within your Kubernetes cluster.

Also, if your container needs are more modest — maybe you don’t need an actual cluster, you just want the containers — the new Zun project makes it possible to run application containers on their own.


**Coming up next**

As always, it’s impossible to sum up 6 months of OpenStack work in a single blog post, but the general idea is that the OpenStack community is clearly thinking about the long term future and planning accordingly. While this release focused on making it possible to run OpenStack at the Edge, the next, code-named Rocky, will see a focus on NFV-related functionality such as minimum bandwidth requirements to ensure service quality.

What’s more, the community is also working on “mutable configuration across services”, which means that as we move into Intelligent Continuous Delivery (ICD) and potentially ever-changing and morphing infrastructure, we’ll be able to change service configurations without having to restart services.









---
[1] https://www.mirantis.com/blog/openstack-embraces-the-future-with-gpu-edge-computing-support/


