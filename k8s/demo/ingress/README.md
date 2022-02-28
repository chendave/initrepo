steps
=====


1. create pods and services

```
kubectl create -f svc/nginx-deployment.yaml
kubectl create -f svc/httpd-deployment.yaml
kubectl create -f svc/service_nginx.yaml
kubectl create -f svc/service_httpd.yaml
```

2. create nginx controller

Either the `mandatory_0.30.yaml` or `baremetal/deploy.yaml` should work

```
kubectl create -f baremetal/deploy.yaml
```

3. create ingress instance

you can play with couple of example here, 
- ingress_basic.yaml   (***/foo will not work since there is no path for that***)
- ingress_rewrite_target.yaml (both /foo and /httpd should work)
- ingress_rewrite_target_auth.yaml (need authentication)
- ingress_rewrite_target_https.yaml (tls related)


4. update client host to hold the host mapping, e.g.

update C:\Windows\System32\drivers\etc\hosts to have

```
10.169.180.51 test.ingress.com
```

5. access your service via your browser, e.g.

http://test.ingress.com/foo

or 

http://test.ingress.com/httpd
