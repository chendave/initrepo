---
title: kubemark + perf_test(clusterloader) 本地性能测试的注意事项
date: 2021-09-21 12:35:43
tags: Kubernetes
---

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/绍兴.jpg "6月13日在绍兴")
                                   <center>6月13日在绍兴</center>


在用kubemark做k8s性能测试的时候踩过一些坑，整理记录一下，免得再次踩坑。


kubemark的架构描述以及原理参考[1],[2].


环境搭建以及跑benchmark需要注意的事项：

- Kubemark的master节点，也就是一个单一的all-in-one的节点最好加上一个"master"的后缀，老版本中需要这个信息来判断是否是控制节点，现在的版本应该没有这个要求了，但是最好还是加上这个后缀.
  例如以kubeadm搭建的环境可以通过"node-name"这个参数来覆盖默认值。
  ```
   kubeadm init --apiserver-advertise-address 10.10.36.51 --node-name node-master --pod-network-cidr=10.244.0.0/16
  ```

- client端需要支持无密码登陆到kubemark的master节点，clusterloader需要通过ssh连接到master节点获取节点信息。
  ```bash
   ssh-copy-id -i id_rsa.pub root@10.10.36.51
  ```

- 需要开放的端口，当测试的机器在云上时，这个配置额外需要注意，因为有些端口是被禁的，而clusterloader则需要通过这些端口来收集数据，例如：
  etcd 2381 2379
  kube-schedule 10259
  kube-controller-manager 10257
  cni/weave 6781/6782/6784

- 让scheduler和controller manager放行metrics endpoints，因为clusterloader会收集metrics数据。或者通过配置授权来让用户通过认证。
    ```
      kube-scheduler.yaml
         spec:
           containers:
           - command:
             ...
             - --bind-address=0.0.0.0
             - --authorization-always-allow-paths=/healthz,/metrics
    ```

- 跑benchmark之前需要设置的环境变量，详见测试脚本[安装脚本](https://github.com/chendave/initrepo/blob/5812fc081916f4ed6bffff6c20c65cc12a37ff14/k8s/demo/kubemark/test.sh "install scripts")。
  ```
  KUBE_SSH_USER=root
  KUBEMARK_SSH_KEY="/root/.ssh/id_rsa"
  ```

- hollow node的一些配置，
  - 设置用fake node的image service, 否则默认用的host上的image service。
        ```  hollow-node.yaml
	  command: [
	    "/kubemark",
	    "--morph=kubelet",
	    "--use-host-image-service=false",	         // 这里！
	    "--name=$(NODE_NAME)",
	    "--kubeconfig=/kubeconfig/kubelet.kubeconfig",
	    "--log-file=/var/log/kubelet-$(NODE_NAME).log",
	    "--logtostderr=false"
	    #"--max-pods=1000"   //设置最大支持pods数为1000
	  ]
        ```

  - 而如果用host的image service时，需要和host上配置的runtime一致，因为测试框架默认用的是containerd，可以看hollow-node.yaml里mount的containerd，如果host上设置的是其它runtime，则起pods的时候会找不到对应的服务。

  - fakenodes默认也是只支持110个pods，如果需要跑更多的pods需要修改hollow node的启动参数。
           ```  hollow-node.yaml
	      command: [
	        "/kubemark",
	        "--morph=kubelet",
	        "--use-host-image-service=false",
	        "--name=$(NODE_NAME)",
	        "--kubeconfig=/kubeconfig/kubelet.kubeconfig",
	        "--log-file=/var/log/kubelet-$(NODE_NAME).log",
	        "--logtostderr=false"
	        #"--max-pods=1000"   //设置最大支持pods数为1000
	      ]
           ```

  - hollow node无需配置太多资源，20m cpu以及20M memory足矣。
       ```
         hollow-node.yaml
          ...
          resources:
            requests:
              cpu: 20m
              memory: 20M
        ```

- 设置部分组件的`profiling`为`true`, 否则cpu或者mem的pprof文件肯能为空。

  | 组件                    | 设置              |
  |  ----                   | ----              |
  | kube-controller-manager | profiling=true    |
  | kube-api	            | 无需设置          |
  | kube-scheduling         | 无需设置          |
  | etcd                    | enable-pprof=true listen-client-urls=https://0.0.0.0:2379,http://0.0.0.0:2379 |
  
- clusterloader的参数必须指定kubemark的master节点的IP地址，client端需要知道这个信息以收集kubemark对应的cluster的信息。
  ```
  go run cmd/clusterloader.go ... --masterip=10.253.2.39 ...--logtostderr=false
  ```

- 默认etcd的listen端口一般是2381，而代码里的默认值是2382，所以需要告诉clusterloader真实的etcd的监听端口是多少。
  ```
   go run cmd/clusterloader.go ... --etcd-insecure-port=2381 ...--logtostderr=false
  ```

- 测试框架里有默认的throughput的threshold值，但是实际上跑下来经常会超过默认值，可以修改测试的schema以免跑出来一些warning信息。
  ```diff
	--- a/clusterloader2/testing/node-throughput/config.yaml
	+++ b/clusterloader2/testing/node-throughput/config_origin.yaml
	@@ -17,16 +17,19 @@ steps:
	     Method: APIResponsiveness
	     Params:
	       action: reset
	+      threshold: 20s
	   - Identifier: PodStartupLatency
	     Method: PodStartupLatency
	     Params:
	       action: start
        +      threshold: 20s
   ```

- load测试过程中master节点要打taint，单纯的cardon-ed不会阻止某些测试，例如daemonset scheduler到master，会造成期待的与实际起来的pods数量不一致。

 ```
  kubectl taint nodes kubemark-master node-role.kubernetes.io/master=:NoSchedule
 ```

- 本地测试时，一般是不支持PV的dynamic provision的，然而各个cloud的provider可能支持，测试框架中默认支持，所以本地测试的时候需要把pv相关的测试disable。
        ```diff
	  --- a/clusterloader2/testing/load/statefulset.yaml
	  +++ b/clusterloader2/testing/load/statefulset_origin.yaml
	  @@ -1,5 +1,5 @@
	   {{$HostNetworkMode := DefaultParam .CL2_USE_HOST_NETWORK_PODS false}}
	  -{{$EnablePVs := DefaultParam .CL2_ENABLE_PVS true}}
	  +{{$EnablePVs := DefaultParam .CL2_ENABLE_PVS false}}
        ```

- load测试需要disable掉daemonset [3]
       ```diff
	  --- a/clusterloader2/testing/load/modules/reconcile-objects.yaml
	  +++ b/clusterloader2/testing/load/modules/reconcile-objects_origin.yaml
	  @@ -44,10 +44,10 @@

	   ## CL2 params
	   {{$CHECK_IF_PODS_ARE_UPDATED := DefaultParam .CL2_CHECK_IF_PODS_ARE_UPDATED true}}
	  -{{$DISABLE_DAEMONSETS := DefaultParam .CL2_DISABLE_DAEMONSETS false}}
	  +{{$DISABLE_DAEMONSETS := DefaultParam .CL2_DISABLE_DAEMONSETS true}}
	   {{$ENABLE_DNSTESTS := DefaultParam .CL2_ENABLE_DNSTESTS false}}
	   {{$ENABLE_NETWORKPOLICIES := DefaultParam .CL2_ENABLE_NETWORKPOLICIES false}}
	  -{{$ENABLE_PVS := DefaultParam .CL2_ENABLE_PVS true}}
	  +{{$ENABLE_PVS := DefaultParam .CL2_ENABLE_PVS false}}
        ```

其它的一些说明：

1. 单纯的cpu或者mem的profiling，可以不用借助clusterloader，可以直接通过调用url即可获取一段时间的数据，例如：
   - 打开scheduler的不安全端口
         ```diff  kube-scheduler_updated.yaml kube-scheduler_origin.yaml
	   <     - --port=7788
	   ---
	   >     - --port=0
         ```

	 ```bash
          curl -k http://localhost:7788/debug/pprof/profile?seconds=30 -o cpu2.pprof
         ```

   - 配置好用户授权后，也可以通过https端口来后去数据
       ```bash
        curl -k https://localhost:10259/debug/pprof/profile?seconds=30 -o cpu2.pprof
       ```
   
2. 火焰图
   ```
      > go tool pprof http://localhost:7788/debug/pprof/profile?seconds=30 //生成数据，可以在/root/pprof/下找到压缩包
      > web		  						   //通过网页load数据
   ```
   web页面上view的icon下面可以找到`flame graph`，点击即可load火焰图，注意有些组件需要配置非安全端口或者配置好授权之后才可以拉到数据。
   
3. 分析cpu或者mem的profiling数据时，主要有这么几个数据 [4]
   flat: 当前函数的耗时（不包含调用的子函数），所以这个数据一般不大。
   flat%: 占总耗时的百分比。
   sum%: 函数占CPU耗时的累计百分比。
   cum: 当前函数加上其调用的子函数总共的耗时
   cum%: 当前函数加上其调用的子函数总共的耗时占总耗时的百分比，这个参考意义更大一些。
   
   
reference：
------------------
[1] https://github.com/kubernetes/community/blob/master/contributors/devel/sig-scalability/kubemark-guide.md
[2] https://github.com/kubernetes/kubernetes/tree/master/test/kubemark/pre-existing
[3] https://github.com/kubernetes/perf-tests/issues/1878
[4] https://xiazemin.github.io/MyBlog/golang/2020/03/26/cum.html

