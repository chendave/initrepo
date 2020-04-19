# section 1, get your hand dirty
see: https://www.ianlewis.org/en/what-are-kubernetes-pods-anyway

- create nginx config
```bash
cat <<EOF >> nginx.conf
error_log stderr;
events { worker_connections  1024; }
http {
    access_log /dev/stdout combined;
    server {
        listen 80 default_server;
        server_name example.com www.example.com;
        location / {
            proxy_pass http://127.0.0.1:2368;
        }
    }
}
EOF
```

- create nginx container
```bash docker run -d --name nginx -v `pwd`/nginx.conf:/etc/nginx/nginx.conf -p 8080:80 nginx```

- go to webbrower to check the nginx, for example: http://10.169.36.51:8080/
- add the ghost into the nginx

```bash docker run -d --name ghost --net=container:nginx --ipc=container:nginx --ipc=shareable --pid=container:nginx ghost```

- go to webbrower to check the ghost, for example: http://10.169.36.51:8080/ghost/

# section 2: what's the IPC? why it should be configured as shareable in the example above?
see: http://www.chandrashekar.info/articles/linux-system-programming/introduction-to-linux-ipc-mechanims.html

> Inter-Process-Communication (or IPC for short) are mechanisms provided by the kernel to allow processes to communicate with each other. On modern systems, IPCs form the web that bind together each process within a large scale software architecture.
