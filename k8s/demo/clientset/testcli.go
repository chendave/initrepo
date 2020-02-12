//https://uzshare.com/view/793594
package main

import (
	"flag"
	"fmt"
	"context"
	"k8s.io/api/core/v1"
	v12 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	//"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

var (
	//集群配置文件路径
	kubeconfigStr = flag.String("kubeconfig", "default value", "kubernetes config file")
)

func main()  {
	//解析参数
	flag.Parse()

	testClientSet()

	fmt.Println("\nrest")

	testRestClient()

	fmt.Println("\n.....")
	testDynamicClient()
}


func testRestClient() {
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfigStr)
	if err != nil {
		panic(err)
	}

	//原生接口都在/api下，扩展接口在/apis下
	config.APIPath = "/api"
	//pods资源相关的group为空
	config.GroupVersion = &schema.GroupVersion{
		Group:    "",
		Version: "v1",
	}
	//序列化方式，目前json和protocal buf
	config.ContentType = runtime.ContentTypeJSON
	//config.NegotiatedSerializer = serializer.DirectCodecFactory{CodecFactory: scheme.Codecs}
	config.NegotiatedSerializer = scheme.Codecs.WithoutConversion()

	restClient, err := rest.RESTClientFor(config)
	if err != nil {
		panic(err)
	}

	podList := &v1.PodList{}
	//除了Do()方法之外，还有DoRaw()，返回原始的bytes； Do()会做一下类型的转化
	restClient.Get().Resource("pods").Namespace("").Do(context.TODO()).Into(podList)

	fmt.Println(podList)
}


func testClientSet() {
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfigStr)
	if err != nil {
		panic(err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	//一行代码指定group、version、resource、以及动作
	//podList, err := clientset.CoreV1().Pods("kube-system").List(v12.ListOptions{})
	//podInfo, err := clientset.CoreV1().Pods("kube-system").Get("etcd-node-master", v12.GetOptions{})
	//podList, err := clientset.CoreV1().Pods("").List(v12.ListOptions{})
	//podList, err := clientset.CoreV1().Pods("default").List(v12.ListOptions{})
	fmt.Println("below is the pod info")
	fmt.Println(podInfo)
}

func testDynamicClient() {
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfigStr)
	if err != nil {
		panic(err)
	}

	dynamicClient, err := dynamic.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	//指定group、version以及要访问的资源 
	testrcGVR := schema.GroupVersionResource{
		Group:    "",
		Version:  "v1",
		Resource: "pods",
	}

	unstr, err := dynamicClient.Resource(testrcGVR).List(v12.ListOptions{})

	fmt.Println(unstr)
}
