some steps to try the `pv` and `pvc`


- install nfs server on server side
  ```bash
   apt-get install nfs-kernel-server
  ```

- edit the exports file to add the file system we created to be exported to remote hosts.
  ```bash
  # /etc/exports
  /nfsdata/pv1 10.169.214.118/22(rw,sync,no_subtree_check)
  ```

- restart nfs service
  ```bash
  service nfs-kernel-server restart
  ```

- check the shared resource by NFS
  ```bash
  showmount -e 10.169.180.51
  ```


- install packages on the client machine,
  ```bash
  apt install nfs-common
  ```

- create the pod with the pv
  ```bash
  kubectl create -f nfs-pv1.yml
  kubectl create -f nfs-pvc1.yml
  kubectl create -f podpv.yaml
  kubectl create -f podpv2.yaml
  ```

- check the file is shared between the pods,
  ```bash
  cp README.md /nfsdata/pv1/
  kubectl exec -it mypod1 -- ash
  ls /mydata/
  kubectl exec -it mypod2 -- ash
  ls mydata2/
  ```





   
