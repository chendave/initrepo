By default, port type is `ClusterIP`, if you want to use `NodePort` instead, you must explicitly specify it as
`type: NodePort`, then you can define `nodePort` in the `yaml` file.

- `nodePort` is the port on the host.
- `targetPort` is the port in the pod, this is the port required by the service in the docker image, it's the internal port, no matter whether the port is opened on the host or not.
- `port` is how other service connect with the service in the cluster.
