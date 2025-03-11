# Extras - HTTP Mirror

In the event you need to run an HTTP server that can automatically download files before it starts serving them as a mirror, *then you're in luck!*

This application will take in some YAML formatted configuration which points it to files to download, and where to store them.  Once all the files have been downloaded, it starts serving them via HTTP.

The source code for the application can be found here: https://github.com/kenmoini/go-http-mirror

## Building from Source

To build the application from source you will need Golang installed.

```bash
git clone https://github.com/kenmoini/go-http-mirror.git
cd go-http-mirror

# Download deps
go mod tidy

# Build the binary
go build -o http-mirror

# Run the mirror
./http-mirror -config=./container_root/etc/http-mirror/config.yml
```

## Running with Podman

```bash
# Make a directory to store assets
mkdir my-assets

# Run the container, mounting the directory to save assets to, and the path with the configuration
podman run --rm -d \
 --name http-mirror \
 -p 8080:8080 \
 -v ./my-assets:/tmp/server/pub:Z \
 -v ./container_root/etc/http-mirror:/etc/http-mirror:Z \
 quay.io/kenmoini/go-http-mirror:latest
```

## Running on OpenShift

Make sure to modify the ConfigMap/Deployment to suit your needs and simply run:

```bash
# Create a new project
oc new-project http-mirror

# Deploy the Mirror
oc apply -R -f extras/http-mirror/manifests/
```