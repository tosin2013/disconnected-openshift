# Binaries

In order to install and use OpenShift, you'll need some binaries such as `openshift-install` and `oc`, at a minimum.  There are other binaries that are likely helpful such as `oc-mirror`, `opm`, `helm`, `kustomize`, etc.

Note that some of the OpenShift binaries require RHEL and some even at least RHEL 9 to execute.  If you do not have a RHEL 9 system available for use, you may also skip down below and use the Container Image version.

## Downloading/Mirroring the Binaries

You can pull the various OpenShift binaries from:

- **Red Hat Console**: https://console.redhat.com/openshift/downloads
- **HTTP Listing**: https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/

You just need these to be available to systems, eg via an HTTP server or SCP'd over to a terminal.  RHEL does package many of the binaries in RPMs so you could mirror them with Red Hat Satellite if that is a preferred mechanism.

## Helper Script

In this repository you can find a helper script that will go and download the latest OpenShift binaries into a local `./bin/` directory.

```bash
# Run the script
./binaries/download-ocp-binaries.sh

# Check out the files downloaded
ls ./bin/
kubectl
oc
openshift-install
```

## Container Image

In some environments, it may just be easier to ship a lot of binaries and config in a container image.  It also may be easier to use a container image than finding a RHEL system, in case you don't have one on hand.

There are also situations where you may need to deploy OpenShift into a FIPS-enabled environment.  This requires RHEL 9 and a FIPS-enabled RHEL installation.  If you do not have this, you could alternatively use a container image as well - *technically, to an extent*.

```bash
# Build the container image with all our handy binaries
podman build -t ocp-tools -f binaries/Containerfile .
# Or for FIPS goodness...
podman build -t ocp-tools -f binaries/Containerfile.fips .

# Tag the image
podman tag ocp-tools registry.example.com/library/ocp-tools:latest

# Push the image
podman push registry.example.com/library/ocp-tools:latest
```

Then when you need to use the image, just run it and mount a volume for persistent data:

```bash
# Make a directory
mkdir ocp-things

# Run the container
podman run --rm -it \
 -v ./ocp-things:/data:Z \
 registry.example.com/library/ocp-tools:latest \
 /bin/bash
```

Once inside your running container, you can use the binaries and then access the generated assets from your host as well.

## Extra Examples

To support the lifecycle of needing to download newer binaries, there are a few example pipelines to easy the maintenance of OpenShift binaries.

- **GitHub Actions**: Will build/push the container images with OCP binaries
- **Azure DevOps Pipeline**: Will build/push the container images with OCP binaries
- **Tekton**: Will build/push the container images with OCP binaries

By default, these pipelines support building the normal and FIPS-enabled images and just pull the latest file.  In production environments when you want to tie things to versions more closely, you'd duplicate the pipeline, add an argument for passing along a specific version, and make sure the image tags it pushes point to those versions.