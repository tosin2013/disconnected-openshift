# NGINX Container

Sometimes you need to host things with an HTTP server - this could be something like the Agent Based or Assisted Installer ISOs, RHCOS images, Ignition files, etc.

To deploy one in OpenShift is easy, however sometimes you just need a "simple" server running on a Linux host.  If your patterns to support mirroring OpenShift rely heavily on containers, then it makes sense to use a container for an HTTP server when needed.

```bash
# Start the nginx container
podman run -it --rm -d -p 8085:80 \
 -v /my/data/to/serve:/opt/app-root/src:Z \
 registry.access.redhat.com/ubi9/nginx-124:9.5-1741661744

# or - Start the nginx container with directory listing enabled

echo 'server {listen 80; server_name localhost; location / { root /opt/app-root/src; index index.html index.htm; autoindex on; autoindex_exact_size off; }}' > nginx-default.conf

podman run -it --rm -d -p 8085:80 \
 -v /my/data/to/serve:/opt/app-root/src:Z \
 -v ./nginx-default.conf:/etc/nginx/conf.d/default.conf:Z \
 registry.access.redhat.com/ubi9/nginx-124:9.5-1741661744
```