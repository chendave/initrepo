---
title: Kubernetes-从APIServer到Kubelet
date: 2021-02-16 20:40:54
tags: Kubernetes
---

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/崇明.jpg "2月13日在崇明东平森林公园")
                                   <center>2月13日在崇明东平森林公园</center>

总的来说，Kubelet需要监听APIServer的events, 例如pod的创建事件，然后根据具体的事件去调用CRI的接口完成containers的创建，启动等。

这里记录一下部分核心的代码以备后查。
Kubelet启动后定义了对三个消息源的监听，分别是HTTP，File以及APIServer，以APIServer为例，

* APIServer表示来自于API Server的更新 - Apiserver Source identifies updates from Kubernetes API Server.
* file更新来自于一个文件，比方说static pod对应的manifest文件- Filesource idenitified updates from a file.
* http 更新来自于web page, 通过web page传入的static pod配置 - HTTPSource identifies updates from querying a web page.

在创建pod的时候，这部分信息会记录在pod的yaml文件中，以这样的annotation呈现：

> kubernetes.io/config.source: file

```golang
/go/src/k8s.io/kubernetes/pkg/kubelet/kubelet.go
func makePodSourceConfig(kubeCfg *kubeletconfiginternal.KubeletConfiguration, kubeDeps *Dependencies, nodeName types.NodeName) (*config.PodConfig, error) {
	...
	if kubeDeps.KubeClient != nil {
		klog.Infof("Watching apiserver")
		config.NewSourceApiserver(kubeDeps.KubeClient, nodeName, cfg.Channel(kubetypes.ApiserverSource))
	}
	...
}
```

```golang
/go/src/k8s.io/kubernetes/pkg/kubelet/config/apiserver.go
func newSourceApiserverFromLW(lw cache.ListerWatcher, updates chan<- interface{}) {
	send := func(objs []interface{}) {
		var pods []*v1.Pod
		for _, o := range objs {
			pods = append(pods, o.(*v1.Pod))
		}
		updates <- kubetypes.PodUpdate{Pods: pods, Op: kubetypes.SET, Source: kubetypes.ApiserverSource}
	}
	r := cache.NewReflector(lw, &v1.Pod{}, cache.NewUndeltaStore(send, cache.MetaNamespaceKeyFunc), 0)
	go r.Run(wait.NeverStop)
}
```

`cfg.Channel(kubetypes.ApiserverSource)`生成了一个chan，并且定义了一个goroutine来轮询此chan，此chan的输入本质上来自于APIServer通过Reflector的list-watch机制捕获的一些消息。添加，删除等。

```golang
func (m *Mux) Channel(source string) chan interface{} {
	if len(source) == 0 {
		panic("Channel given an empty name")
	}
	...
	newChannel := make(chan interface{})
	m.sources[source] = newChannel
	go wait.Until(func() { m.listen(source, newChannel) }, 0, wait.NeverStop)
	return newChannel
}
```

通过Reflector的list-watch机制，监听APIServer来获取Cache的变更，
```golang
/go/src/k8s.io/kubernetes/vendor/k8s.io/client-go/tools/cache/reflector.go
func (r *Reflector) watchHandler(start time.Time, w watch.Interface, resourceVersion *string, errc chan error, stopCh <-chan struct{}) error {
			...
			switch event.Type {
			case watch.Added:
				err := r.store.Add(event.Object)
				if err != nil {
					utilruntime.HandleError(fmt.Errorf("%s: unable to add watch event object (%#v) to store: %v", r.name, event.Object, err))
				}
			case watch.Modified:
				err := r.store.Update(event.Object)
				if err != nil {
					utilruntime.HandleError(fmt.Errorf("%s: unable to update watch event object (%#v) to store: %v", r.name, event.Object, err))
				}
			case watch.Deleted:
				// TODO: Will any consumers need access to the "last known
				// state", which is passed in event.Object? If so, may need
				// to change this.
				err := r.store.Delete(event.Object)
				if err != nil {
					utilruntime.HandleError(fmt.Errorf("%s: unable to delete watch event object (%#v) from store: %v", r.name, event.Object, err))
				}
			...
}
```

这里的store初始化为`UndeltaStore`， 因此会触发`PushFunc`，也是就是之前在`apiserver.go`里定义的send方法，
```golang
/go/src/k8s.io/kubernetes/pkg/kubelet/config/apiserver.go
	send := func(objs []interface{}) {
		var pods []*v1.Pod
		for _, o := range objs {
			pods = append(pods, o.(*v1.Pod))
		}
		updates <- kubetypes.PodUpdate{Pods: pods, Op: kubetypes.SET, Source: kubetypes.ApiserverSource}
	}
```

```golang
/go/src/k8s.io/kubernetes/vendor/k8s.io/client-go/tools/cache/undelta_store.go
	func (u *UndeltaStore) Add(obj interface{}) error {
		if err := u.Store.Add(obj); err != nil {
			return err
		}
		u.PushFunc(u.Store.List())
		return nil
	}
```


监听到newChannel上有输入时，调用Merge方法来过滤掉一些多余重复的变更，并规范化为一个PodUpdate类型的结构体，发送给`podStorage`chan型成员变量updates。
```golang
func (s *podStorage) Merge(source string, change interface{}) error {
	...
	switch s.mode {
	case PodConfigNotificationIncremental:
		if len(removes.Pods) > 0 {
			s.updates <- *removes
		}
		if len(adds.Pods) > 0 {
			s.updates <- *adds
		}
		if len(updates.Pods) > 0 {
			s.updates <- *updates
		}
		if len(deletes.Pods) > 0 {
			s.updates <- *deletes
		}
	...
}
```

podStorage用在PodConfig的初始化步骤里，
```golang
/go/src/k8s.io/kubernetes/pkg/kubelet/config/config.go
func NewPodConfig(mode PodConfigNotificationMode, recorder record.EventRecorder) *PodConfig {
	updates := make(chan kubetypes.PodUpdate, 50)
	storage := newPodStorage(updates, mode, recorder)
	podConfig := &PodConfig{
		pods:    storage,
		mux:     config.NewMux(storage),  // podStorage转为会Mux类型，所以可以调用去Merge方法对变更进行规范化。
		updates: updates,	// updates是我们需要的主要结构体，后续需要根据这个结构来分析不同的事件。
		sources: sets.String{},
	}
	return podConfig
}
```


```golang
/go/src/k8s.io/kubernetes/pkg/kubelet/kubelet.go
func NewMainKubelet(kubeCfg *kubeletconfiginternal.KubeletConfiguration,
	...
	if kubeDeps.PodConfig == nil {
		var err error
		kubeDeps.PodConfig, err = makePodSourceConfig(kubeCfg, kubeDeps, nodeName)
		if err != nil {
			return nil, err
		}
	}
	...
}
```

`makePodSourceConfig`调用了`NewPodConfig`来创建`podconfig`，并赋值给`kubeDeps.PodConfig`，接着在`RunKubelet`方法中赋值给podCfg，

```golang
/go/src/k8s.io/kubernetes/cmd/kubelet/app/server.go
func RunKubelet(kubeServer *options.KubeletServer, kubeDeps *kubelet.Dependencies, runOnce bool) error {
        ...
	podCfg := kubeDeps.PodConfig
	...
	// process pods and exit.
	if runOnce {
		if _, err := k.RunOnce(podCfg.Updates()); err != nil {  
			return fmt.Errorf("runonce failed: %v", err)
		}
		klog.Info("Started kubelet as runonce")
	} else {
		startKubelet(k, podCfg, &kubeServer.KubeletConfiguration, kubeDeps, kubeServer.EnableCAdvisorJSONEndpoints, kubeServer.EnableServer)
		klog.Info("Started kubelet")
	}
	return nil
	...
```

startKubelet方法启动kubelet,
```golang
func startKubelet(k kubelet.Bootstrap, podCfg *config.PodConfig, kubeCfg *kubeletconfiginternal.KubeletConfiguration, kubeDeps *kubelet.Dependencies, enableCAdvisorJSONEndpoints, enableServer bool) {
	// start the kubelet
	go k.Run(podCfg.Updates())  //podCfg.Updates()获取updates结构体
	...
}
```


这里就很清楚了，updates结构体被用在syncLoop方法中，也就是通过各个handler来调用底层的CRI来实现pod的增删改等操作。
```golang
/go/src/k8s.io/kubernetes/pkg/kubelet/kubelet.go
func (kl *Kubelet) Run(updates <-chan kubetypes.PodUpdate) {
	...
	// Start the pod lifecycle event generator.
	kl.pleg.Start()
	kl.syncLoop(updates, kl)
}

func (kl *Kubelet) syncLoopIteration(configCh <-chan kubetypes.PodUpdate, handler SyncHandler,
	syncCh <-chan time.Time, housekeepingCh <-chan time.Time, plegCh <-chan *pleg.PodLifecycleEvent) bool {
	...
	select {
	case u, open := <-configCh:
		// Update from a config source; dispatch it to the right handler
		// callback.
		if !open {
			klog.Errorf("Update channel is closed. Exiting the sync loop.")
			return false
		}

		switch u.Op {
		case kubetypes.ADD:
		...
			klog.V(2).Infof("SyncLoop (ADD, %q): %q", u.Source, format.Pods(u.Pods))
			// After restarting, kubelet will get all existing pods through
			// ADD as if they are new pods. These pods will then go through the
			// admission process and *may* be rejected. This can be resolved
			// once we have checkpointing.
			handler.HandlePodAdditions(u.Pods)
		...
}
```
