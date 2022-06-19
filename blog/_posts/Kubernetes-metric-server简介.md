---
title: Kubernetes - metric server简介
date: 2022-06-16 16:24:28
thumbnail: /css/images/世博.jpg
tags: Kubernetes
---

关于metric server的一些随笔。

总得说来，metric server可以获取node和pod的使用了多少CPU或者memory的资源，其底层实现是通过cadvisor调用了runc的接口来读取例如CPU和memory的使用信息。

官网上的一个metric资源访问流。
![](https://github.com/chendave/chendave.github.io/raw/master/css/images/resource-pipeline.png)

**安装**
```kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml```

在测试场景下，我们还需要启动metric server的启动命令行上加上 `kubelet-insecure-tls`参数以表示不需要对kubelet的证书进行校验。

**验证**

```bash
root@a010735:~# kubectl top nodes
NAME      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
a010735   372m         4%     6359Mi          40%
root@a010735:~# kubectl top pods
NAME                          CPU(cores)   MEMORY(bytes)
init-demo                     0m           1Mi
php-apache-6db6dccd7f-569pp   1m           14Mi
```

**源码分析（commit ID: bb893870b2）**：
- API 注册：
apiserver启动后会注册metric server的endpoints, 项目地址为：https://github.com/kubernetes-sigs/metrics-server.

对应的代码实现：
```golang
metrics-server/pkg/api/install.go
// Install builds the metrics for the metrics.k8s.io API, and then installs it into the given API metrics-server.
func Install(m MetricsGetter, podMetadataLister cache.GenericLister, nodeLister corev1.NodeLister, server *genericapiserver.GenericAPIServer) error {
	node := newNodeMetrics(metrics.Resource("nodemetrics"), m, nodeLister)
	pod := newPodMetrics(metrics.Resource("podmetrics"), m, podMetadataLister)
	info := Build(pod, node)
	return server.InstallAPIGroup(&info)
}
```

访问的API具体地址：
- 访问某一个pod的metric数据
https://127.0.0.1:6443/apis/metrics.k8s.io/v1beta1/namespaces/default/pods/demo
- 访问所有pods的metric数据
https://127.0.0.1:6443/apis/metrics.k8s.io/v1beta1/namespaces/default/pods
- 访问某一个node的metric数据
https://127.0.0.1:6443/apis/metrics.k8s.io/v1beta1/nodes/node1
- 访问所有nodes的metric数据
https://127.0.0.1:6443/apis/metrics.k8s.io/v1beta1/nodes

> **_NOTE:_** API的定义另一个项目里：https://github.com/kubernetes/metrics, metric-server相当于实现了该项目定义的API。

```golang
pkg/apis/metrics/register.go
// GroupName is the group name use in this package
const GroupName = "metrics.k8s.io"

// SchemeGroupVersion is group version used to register these objects
var SchemeGroupVersion = schema.GroupVersion{Group: GroupName, Version: runtime.APIVersionInternal}
```

- 数据存储
metric server用来存储node和pod的metric数据的数据结构：
```golang
metrics-server/pkg/storage/storage.go
type storage struct {
	mu    sync.RWMutex
	pods  podStorage
	nodes nodeStorage
}
```

后面通过runc的接口获取到的数据会存储到这个数据结构中，并通过计算得到当前node或者pod的资源利用情况。metric server的定时任务每隔一定时间会调用scrape和store接口来刷新数据。

```golang
metrics-server/pkg/server/server.go
func (s *server) tick(ctx context.Context, startTime time.Time) {
	s.tickStatusMux.Lock()
	s.tickLastStart = startTime
	s.tickStatusMux.Unlock()

	ctx, cancelTimeout := context.WithTimeout(ctx, s.resolution)
	defer cancelTimeout()

	klog.V(6).InfoS("Scraping metrics")
	data := s.scraper.Scrape(ctx)

	klog.V(6).InfoS("Storing metrics")
	s.storage.Store(data)

	collectTime := time.Since(startTime)
	tickDuration.Observe(float64(collectTime) / float64(time.Second))
	klog.V(6).InfoS("Scraping cycle complete")
}
```

原始数据的收集的核心调用是通过`func (c *scraper) collectNode(ctx context.Context, node *corev1.Node) (*storage.MetricsBatch, error)`方法来获取数据并存入`storage.MetricsBatch`数据结构中。

```golang
metrics-server/pkg/scraper/scraper.go
func (c *scraper) Scrape(baseCtx context.Context) *storage.MetricsBatch {
	…
	for _, node := range nodes {
		go func(node *corev1.Node) {
			// Prevents network congestion.
			sleepDuration := time.Duration(rand.Intn(delayMs)) * time.Millisecond
			time.Sleep(sleepDuration)
			// make the timeout a bit shorter to account for staggering, so we still preserve
			// the overall timeout
			ctx, cancelTimeout := context.WithTimeout(baseCtx, c.scrapeTimeout-sleepDuration)
			defer cancelTimeout()
			klog.V(2).InfoS("Scraping node", "node", klog.KObj(node))
			<mark>m, err := c.collectNode(ctx, node)</mark>
			if err != nil {
				klog.ErrorS(err, "Failed to scrape node", "node", klog.KObj(node))
			}
			responseChannel <- m
		}(node)
	}
	…
}
```

这里`collectNode`方法是通过kubelet连接到各个不同的node，通过`/metrics/resource` URI来读取数据。

```golang
metrics-server/pkg/scraper/client/resource/client.go
func (kc *kubeletClient) GetMetrics(ctx context.Context, node *corev1.Node) (*storage.MetricsBatch, error) {
	port := kc.defaultPort
	nodeStatusPort := int(node.Status.DaemonEndpoints.KubeletEndpoint.Port)
	...
	url := url.URL{
		Scheme: kc.scheme,
		Host:   net.JoinHostPort(addr, strconv.Itoa(port)),
		<strong>Path:   "/metrics/resource",</strong>
	}
	...
	return kc.getMetrics(ctx, url.String(), node.Name)
}
```

`/metrics/resource`这个URI对应的处理逻辑在kubelet中实现，
```golang
k8s.io/kubernetes/pkg/kubelet/server/server.go

const resourceMetricsPath = "/metrics/resource"
func (s *Server) InstallDefaultHandlers() {
        …
	s.addMetricsBucketMatcher("metrics/resource")
	resourceRegistry := compbasemetrics.NewKubeRegistry()
	resourceRegistry.CustomMustRegister(collectors.<mark>NewResourceMetricsCollector</mark>(s.resourceAnalyzer))
	s.restfulCont.Handle(resourceMetricsPath,
		compbasemetrics.HandlerFor(resourceRegistry, compbasemetrics.HandlerOpts{ErrorHandling: compbasemetrics.ContinueOnError}),
	)
	…
}
```

`NewResourceMetricsCollector`返回`metrics.StableCollector`接口，metric主要通过实现接口中方法`CollectWithStability`来收集数据。

```golang
k8s.io/kubernetes/pkg/kubelet/metrics/collectors/resource_metrics.go
func (rc *resourceMetricsCollector) CollectWithStability(ch chan<- metrics.Metric) {
	...
	statsSummary, err := rc.provider.GetCPUAndMemoryStats()  // 1)
	if err != nil {
		errorCount = 1
		klog.ErrorS(err, "Error getting summary for resourceMetric prometheus endpoint")
		return
	}

	rc.collectNodeCPUMetrics(ch, statsSummary.Node) // 2)
	rc.collectNodeMemoryMetrics(ch, statsSummary.Node) // 3)

	for _, pod := range statsSummary.Pods {
		for _, container := range pod.Containers {
			rc.collectContainerStartTime(ch, pod, container)
			rc.collectContainerCPUMetrics(ch, pod, container)
			rc.collectContainerMemoryMetrics(ch, pod, container)
		}
		rc.collectPodCPUMetrics(ch, pod) // 4)
		rc.collectPodMemoryMetrics(ch, pod) // 5)
	}
}
```

1. statsSummary, err := rc.provider.GetCPUAndMemoryStats() // 通过kubelet调用cadvisor方法读取CPU和memory的统计信息，包括node和active的容器。
2. rc.collectNodeCPUMetrics(ch, statsSummary.Node) // 生成cpu的metric，计算方法：float64(*s.CPU.UsageCoreNanoSeconds)/float64(time.Second)
3. rc.collectNodeMemoryMetrics(ch, statsSummary.Node) // 生成memory的metric，计算方法：float64(*s.Memory.WorkingSetBytes)
4. rc.collectPodCPUMetrics(ch, pod) // 生成pod的CPU metric，计算方法：float64(*pod.CPU.UsageCoreNanoSeconds)/float64(time.Second)
5. rc.collectPodMemoryMetrics(ch, pod) // 生成pod的memory metric，计算方法：float64(*pod.Memory.WorkingSetBytes) 对于pod上的每个容器也一并计算生成容器的开始时间以及CPU和memory的使用情况。

深入看一下`statsSummary, err := rc.provider.GetCPUAndMemoryStats()`这个方法调用。总的说来，是通过调用cadvisor（cadvisor已经和kubelet集成）并最终调用runc的cgroup接口来读入数据。

cadvisor将数据存放在cache中，这部分在kubelet中实现，
```golang
k8s.io/kubernetes/pkg/kubelet/stats/provider.go
func getCgroupInfo(cadvisor cadvisor.Interface, containerName string, updateStats bool) (*cadvisorapiv2.ContainerInfo, error) {
	...
	infoMap, err := <mark>cadvisor.ContainerInfoV2</mark>(containerName, cadvisorapiv2.RequestOptions{
		IdType:    cadvisorapiv2.TypeName,
		Count:     2, // 2 samples are needed to compute "instantaneous" CPU
		Recursive: false,
		MaxAge:    maxAge,
	})
	...
}
```

读取cache，开始和结束时间都置为空，实际上是读取了所有的数据。
```golang
github.com/google/cadvisor/manager/manager.go
stats, err := m.memoryCache.RecentStats(name, nilTime, nilTime, options.Count)
```


- Cadvisor与runc

Cadvisor也启动了一个定时任务，每隔一段时间会将最新的数据刷到内存中。
```golang
github.com/google/cadvisor/manager/container.go
func (cd *containerData) housekeepingTick(timer <-chan time.Time, longHousekeeping time.Duration) bool
```

可以去看看数据是如何从cgroup接口获取的。
```golang
func (cd *containerData) updateStats() error {
	stats, statsErr := <mark>cd.handler.GetStats()</mark>
	...
	perfStatsErr := cd.perfCollector.UpdateStats(stats)

	resctrlStatsErr := cd.resctrlCollector.UpdateStats(stats)		
	...
	err = cd.memoryCache.AddStats(&cInfo, stats)
}
```

这里handler根据底层runtime的不同调用有不同的具体实现，例如`containerd`或者`crio`，但是最后都会调入到`libcontainer`中去。

```golang
github.com/google/cadvisor/container/libcontainer/handler.go
func (h *Handler) GetStats() (*info.ContainerStats, error) {
	...
	<mark>cgroupStats, err := h.cgroupManager.GetStats()</mark>
	if err != nil {
		if !ignoreStatsError {
			return nil, err
		}
		klog.V(4).Infof("Ignoring errors when gathering stats for root cgroup since some controllers don't have stats on the root cgroup: %v", err)
	}
	...
}
```

可以打印出`h.cgroupManager`的path可以发现就本质就是cgroup的各个子系统。Cgroup manager可以是systemd，fs或者fs2等，以fs为例。
```golang
paths: map[string]string [
        "cpu": "/sys/fs/cgroup/cpu,cpuacct",
        "memory": "/sys/fs/cgroup/memory",
        "cpuacct": "/sys/fs/cgroup/cpu,cpuacct",
        "blkio": "/sys/fs/cgroup/blkio",
        "devices": "/sys/fs/cgroup/devices",
]
```

libcontainer调用各个子系统的GetStats方法得到数据。
```golang
/go/src/k8s.io/kubernetes/vendor/github.com/opencontainers/runc/libcontainer/cgroups/fs/fs.go
func (m *manager) GetStats() (*cgroups.Stats, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	<mark>stats := cgroups.NewStats()</mark>
	for _, sys := range subsystems {
		path := m.paths[sys.Name()]
		if path == "" {
			continue
		}
		if err := sys.GetStats(path, stats); err != nil {
			return nil, err
		}
	}
	return stats, nil
}
```

看看cpuacct是如何读取的数据，可以简单的理解为文件读取并做了一定的处理。
```golang
vendor/github.com/opencontainers/runc/libcontainer/cgroups/fs/cpuacct.go
func (s *CpuacctGroup) GetStats(path string, stats *cgroups.Stats) error {
	...
	totalUsage, err := fscommon.GetCgroupParamUint(path, "cpuacct.usage")
	if err != nil {
		return err
	}
	...
	percpuUsage, err := getPercpuUsage(path)
	if err != nil {
		return err
	}
	...
}
```

比方说我们可以在系统上读取`cpuacct.usage`或者`cpuacct.usage_percpu`。
```bash
/sys/fs/cgroup/cpu,cpuacct# cat cpuacct.usage
5842504834476978
```

- Metric 与 kubectl
当一个CLI的命令例如：`kubectl top node`发出之后，首先进入的入口定义在这里，
```golang
k8s.io/kubectl/pkg/cmd/top/top.go
func NewCmdTop(f cmdutil.Factory, streams genericclioptions.IOStreams) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "top",
		Short: i18n.T("Display resource (CPU/memory) usage"),
		Long:  topLong,
		Run:   cmdutil.DefaultSubCommandRun(streams.ErrOut),
	}

	// create subcommands
	<mark>cmd.AddCommand(NewCmdTopNode(f, nil, streams))</mark>
	<mark>cmd.AddCommand(NewCmdTopPod(f, nil, streams))</mark>

	return cmd
}
```

调用api接口获取数据然后打印数据到终端，
```golang
k8s.io/kubectl/pkg/metricsutil/metrics_printer.go
func printMetricsLine(out io.Writer, metrics *ResourceMetricsInfo) {
	printValue(out, metrics.Name)
	<mark>printAllResourceUsages(out, metrics)</mark>
	fmt.Fprint(out, "\n")
}
```

实际上就是计算了使用的资源并和机器上的可用资源相除取整并打印输出。
```golang
func printAllResourceUsages(out io.Writer, metrics *ResourceMetricsInfo) {
	for _, res := range MeasuredResources {
		quantity := metrics.Metrics[res]
		printSingleResourceUsage(out, res, quantity)
		fmt.Fprint(out, "\t")
		if available, found := metrics.Available[res]; found {
			<mark>fraction := float64(quantity.MilliValue()) / float64(available.MilliValue()) * 100</mark>
			fmt.Fprintf(out, "%d%%\t", int64(fraction))
		}
	}
}
```

**Metric server的应用场景**

- HPA (Horizontal Pod Autoscaler): 主要是解决当某种类型的workload对象占用资源超过一定数量之后需要增加更多的pod以缓解client端访问的压力（https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/）

- [VPA(Vertical Pod Autoscaler)](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)：解决当pod的request的资源小于实际pod需要的资源数量之后，需要增加pod的request数量应该采取的措施。例如重新定义request的值，并创建一个新的pod。

