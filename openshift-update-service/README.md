# OpenShift Update Service (OSUS)

OpenShift updates are coordinated via a Graph Database.  This allows the ability to associate upgrade paths between versions.  You can learn more about it [here](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/disconnected_environments/updating-a-cluster-in-a-disconnected-environment#updating-disconnected-cluster-osus).

Normally, a connected cluster can just talk to the hosted graph database API that Red Hat provides online.

However, in a disconnected cluster, you can't talk to that graph database API that Red Hat provides online.

So you have two choices:

- [Force updates between versions and hope things work out](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/disconnected_environments/updating-a-cluster-in-a-disconnected-environment#updating-disconnected-cluster)
- [Run an OpenShift Update Service instance to provide the graph database API internally](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/disconnected_environments/updating-a-cluster-in-a-disconnected-environment#updating-disconnected-cluster-osus)

We'll go with the latter since computers and hope/luck don't mix.

## Creating the Graph Database Container

Assuming you have your OpenShift Releases already mirrored, all we really have to do is build a container that goes out to the Internet, downloads the Graph Database, and stores it in a special place for use by OSUS.  This is the minimal `Containerfile` needed to build it:

```
# podman build -t osus-graph-data .
# podman tag osus-graph-data registry.acme.com/manual-mirrored-things/osus-graph-data:latest
# podman push registry.acme.com/manual-mirrored-things/osus-graph-data:latest

FROM registry.access.redhat.com/ubi9/ubi:latest

RUN curl -L -o cincinnati-graph-data.tar.gz https://api.openshift.com/api/upgrades_info/graph-data

# The following command is used to extract the graph data tarball and remove unwanted channels/versions
RUN mkdir -p /var/lib/cincinnati-graph-data && tar xvzf cincinnati-graph-data.tar.gz -C /var/lib/cincinnati-graph-data/ --no-overwrite-dir --no-same-owner

CMD ["/bin/bash", "-c" ,"exec cp -rp /var/lib/cincinnati-graph-data/* /var/lib/cincinnati/graph-data"]
```

You can find a more [optimized Containerfile in this repo](./Containerfile) - no need to keep track of OCP 4.4.

You may also find the following Tekton resources to build it:

- [Task, buildah-disconnected](../tekton/tasks/buildah-disconnected.yml) - Additional configuration for disconnected networks when using buildah to build images
- [Pipeline, Build Container - OSUS Graph Data](../tekton/pipelines/build-container-osus-graph-data.yml) - Pipeline to build the OpenShift Update Service (OSUS) Graph Data container and push to the internal registry
- PipelineRuns for the Pipeline are included as well

## Deploying OpenShift Update Service

In order to use this container we just built, we need to deploy the OpenShift Update Service Operator.

So yes, in order to proceed, you need to have your OpenShift Release practice down, and Operator Catalogs fixed up.

Install the Operator, and create an instance such as the one below:

```yaml
---
kind: UpdateService
apiVersion: updateservice.operator.openshift.io/v1
metadata:
  name: osus
  namespace: openshift-update-service
spec:
  # One replica should be fine - allegedly, Red Hat only runs 1 to serve the global connected fleet
  replicas: 1
  # The OSUS Graph Data Image - this is the default image path created by the included Tekton Pipeline
  graphDataImage: image-registry.openshift-image-registry.svc:5000/openshift-update-service/osus-graph-data:latest

  # Where OCP Releases have been mirrored to
  # Note: This is the Index of the release images
  releases: registry.acme.com/manual-mirror-things/openshift/release-images
  # Other Notes: You cannot use a pull-through/proxy cache via JFrog for this.  There is a bug with enumerating the 12k+ images in the repo.
  # https://jfrog.atlassian.net/browse/RTFACT-18971
  # The workaround is to manually mirror the images for specific releases you want to upgrade to.

  # For Harbor pull-through/proxy caches, it will try to mirror all 12k+ images in the upstream repo.  You don't want this.
  # The workaround is to manually mirror the images for specific releases you want to upgrade to.
```

In the `openshift-update-service` Namespace/Project you should see a series of Pods deployed - for some reason it creates the Deployment, then modifies it, which creates two ReplicaSets, one of which will scale down once the oldest one finishes.

## Configuring OpenShift to use the OSUS UpdateService Instance

With the OSUS UpdateService created, you should be able to validate that all the components are ready once it has a `.status.policyEngineURI`

```bash
# Get the Route to the hosted OSUS Instance
POLICY_ENGINE_GRAPH_URI="$(oc -n openshift-update-service get -o jsonpath='{.status.policyEngineURI}/api/upgrades_info/v1/graph{"\n"}' updateservice osus)"
```

With that Route, you can now configure it for use by a cluster by patching the ClusterVersion CR:

```bash
# Create the Patch JSON
PATCH="{\"spec\":{\"upstream\":\"${POLICY_ENGINE_GRAPH_URI}\"}}"

# Patch the ClusterVersion
oc patch clusterversion version -p $PATCH --type merge
```

With that, you should see your available OpenShift releases for upgrades as long as the paths make them available in the graph database.  If it's taking too long to reconcile an update you can delete the `cluster-version-operator-nnnnn-yyyyy` Pod in the `openshift-cluster-version` Namespace to kick start things.

---

## Debugging

### 'release-manifests/release-metadata' not found

If you deploy the OSUS instance and you see error messages in the Pod logs along the lines of `Could not assemble metadata from layer (sha256:xyz): 'release-manifests/release-metadata' not found` then it could be two things:

1. You have the OSUS instance configured pointing to the larger list of OpenShift Platform images and not the OpenShift Release images.  It will try to enumerate the hundreds of images in there, not find the data it needs, and enter an OOMKilled/CrashloopBackOff state.
2. You have both OpenShift Platform images and OpenShift Release images in the same repo path - they must be in separate paths.

See this poorly worded KCS: https://access.redhat.com/solutions/6976534

### Switching cluster versions gives a signature validation error

OpenShift Releases are signed by a GPG key - the public key that signs it needs to be added to a cluster via a ConfigMap.  See the [openshift-release/make-ocp-release-signature.sh](../openshift-release/make-ocp-release-signature.sh) script for how to generate it.

### x509 TLS Validation error

If you add your OSUS Route to the ClusterVersion CR and it returns an x509 TLS validation error there are a few things to check:

1. That you have a ConfigMap created for the Root CAs signing the TLS endpoint for Image registries

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-image-registry-roots
  namespace: openshift-config
data:
  # This special key is needed for use with OSUS
  updateservice-registry: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----

  # Root CA for specific registries to trust
  disconn-harbor.d70.kemo.labs: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----

```

2. Check that all your needed Root CAs are added to the global additional trust bundle:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-ca-bundle
  namespace: openshift-config
data:
  # Global Proxy Additional Trust Bundle
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    ... your root CAs
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... all of them
    -----END CERTIFICATE-----
```

3. Your Image CR is configured to use the above ConfigMap:

```yaml
---
apiVersion: config.openshift.io/v1
kind: Image
metadata:
  name: cluster
spec:
  additionalTrustedCA:
    name: my-image-registry-roots
```

4. Your global Proxy CR is configured to use the global additional trust bundle - even if you don't use an Outbound Proxy.

```yaml
---
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  name: cluster
spec:
  trustedCA:
    name: user-ca-bundle
```