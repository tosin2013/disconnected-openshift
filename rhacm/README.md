# Red Hat Advanced Cluster Management

## CVO Upstream Policy Example

When managing a fleet of clusters you can leverage things like GitOps - but maybe a policy driven approach would be better for some things?

You can find an example of an ACM Policy that will configure your targeted clusters to use a specified upstream OpenShift Update Service.

Simply install ACM, run `oc apply -k rhacm/`, and if your OSUS instance is running on that same ACM Hub then any cluster with the `cvo-upstream-hub-osus=true` label will have its ClusterVersion CR configured to use that OSUS instance.

---

## ACM Disconnected Configuration

With ACM you can deploy additional services like the Assisted Service/Host Inventory controllers, Hosted Control Planes, etc.  Some of those services need additional configuration to use extra Root CAs, outbound proxies, and so on.

> There are ways to use outbound proxies with ACM AppSubs but please just use a better GitOps mechanism instead.

### Shared - Release Images via ClusterImageSets

> For disconnected/proxied environments, and/or with private (mirror) image registries

If you're not using the release images from Red Hat, which is likely in a disconnected network - you'll need to point to where the OpenShift Release Images are located:

```yaml
---
apiVersion: hive.openshift.io/v1
kind: ClusterImageSet
metadata:
  name: openshift-v41712
  labels:
    channel: stable
    visible: 'true'
spec:
  # If you have ImageTagMirrorSet(s) enabled on your cluster
  releaseImage: quay.io/openshift-release-dev/ocp-release:4.17.12-x86_64
  # If you do not have ITMS/IDMS enabled on the cluster
  #releaseImage: quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-release:4.17.12-x86_64
---
apiVersion: hive.openshift.io/v1
kind: ClusterImageSet
metadata:
  name: openshift-v41630
  labels:
    channel: stable
    visible: 'true'
spec:
  # If you have ImageTagMirrorSet(s) enabled on your cluster
  #releaseImage: quay.io/openshift-release-dev/ocp-release:4.16.30-x86_64
  # If you do not have ITMS/IDMS enabled on the cluster
  releaseImage: quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-release:4.16.30-x86_64
```

> You could easily store these in the `rhacm/` folder and GitOps them to the Hub.

### Assisted Service - Create Mirror Registry ConfigMap

If you're using some mirror image registries and/or custom Root CAs that sign it, you'll need to create a ConfigMap before deploying the Assisted Service - modify as needed to point to your mirror endpoint paths:

```yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: mirror-registry-config
  namespace: multicluster-engine
data:
  # Root CA for your Image Registry
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    MII...
    -----END CERTIFICATE-----
  registries.conf: |
    unqualified-search-registries = ["quay-ptc.jfrog.lab.kemo.network", "registry.access.redhat.com", "quay.io", "docker.io"]
    [[registry]]
      prefix = ""
      location = "quay.io/openshift-release-dev/ocp-release"
      mirror-by-digest-only = true
      [[registry.mirror]]
        location = "quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-release"
    [[registry]]
      prefix = ""
      location = "quay.io/ocpmetal/assisted-installer"
      mirror-by-digest-only = false
      [[registry.mirror]]
        location = "quay-ptc.jfrog.lab.kemo.network/ocpmetal/assisted-installer"
    [[registry]]
      prefix = ""
      location = "quay.io/ocpmetal/assisted-installer-agent"
      mirror-by-digest-only = false
      [[registry.mirror]]
        location = "quay-ptc.jfrog.lab.kemo.network/ocpmetal/assisted-installer-agent"
    [[registry]]
      prefix = ""
      location = "quay.io/openshift-release-dev/ocp-v4.0-art-dev"
      mirror-by-digest-only = true
      [[registry.mirror]]
        location = "quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-v4.0-art-dev"
    [[registry]]
      prefix = ""
      location = "quay.io"
      mirror-by-digest-only = false
      [[registry.mirror]]
        location = "quay-ptc.jfrog.lab.kemo.network"
    [[registry]]
      prefix = ""
      location = "registry.redhat.io"
      mirror-by-digest-only = false
      [[registry.mirror]]
        location = "registry-redhat-ptc.jfrog.lab.kemo.network"
    [[registry]]
      prefix = ""
      location = "registry.connect.redhat.com"
      mirror-by-digest-only = false
      [[registry.mirror]]
        location = "registry-connect-redhat-ptc.jfrog.lab.kemo.network"
```

> You need to also have the ACM Hub cluster's Image CR configured with the `.spec.additionalTrustedCA.name` as detailed in the [Post-Install Config documentation](../post-install-config/README.md#image-cr-configuration).  If you configured it after deploying ACM/MCE/HCP, then you will need to restart the operator-controller pods on their namespaces for them to consume the new config.

### Assisted Service - Assisted Service Overrides

You can override some of the environment variables used by the Assisted Service with a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: assisted-service-config
  namespace: multicluster-engine
  labels:
    app: assisted-service
data:
  LOG_LEVEL: "debug"
  AUTH_TYPE: "none"
  SKIP_CERT_VERIFICATION: "True" # Needed due to issues with mounting CA certs
  ISO_IMAGE_TYPE: "full-iso"

  # ========================================================================================
  # Disconnected/Private Registry Configuration
  # ========================================================================================
  # HTTP_PROXY: "http://proxy.kemo.labs:3129"
  # HTTPS_PROXY: "http://proxy.kemo.labs:3129"
  # NO_PROXY: ".kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local"
```

Then this ConfigMap is specified below when the Assisted Service is enabled.

### Assisted Service - HTTP Mirror for RHCOS Images

By default, RHACM doesn't enable the Assisted Service that manages RHCOS images.  To do so is pretty easy, unless you're in a disconnected/proxied environment cause there's no way to define an outbound proxy to be used by it - and if you're fully disconnected then you need to mirror the RHCOS image parts any way.

To make this easy in an OpenShift hub cluster that has outbound proxy access, there is a `http-mirror` application that can take in proxy configuration, download assets, and host them to be then used by the Assisted Service.  You can find this in the [./extras/http-mirror/](./extras/http-mirror/) directory with the defaults already set up for mirroring 4.18 RHCOS image assets.

### Assisted Service - Configuration Overrides

The Assisted Service handles creating installation ISOs for our managed clusters - with everything in place, we can now deploy it:

```yaml
# 01-setup/manifests/acm-mce-hcp/mce_agentserviceconfig.yaml
---
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
  name: agent
  annotations:
    # ConfigMap from earlier
    unsupported.agent-install.openshift.io/assisted-service-configmap: "assisted-service-config"
    unsupported.agent-install.openshift.io/assisted-image-service-skip-verify-tls: "true"
###
spec:
  databaseStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 10Gi
  filesystemStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 50Gi
  imageStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 50Gi

# ========================================================================================
# Disconnected/Private Registry Configuration
# ========================================================================================
  # The ConfigMap with the mirror config
  mirrorRegistryRef:
    name: mirror-registry-config
  # Locations for OS Images, pulled from the HTTP Mirror deployment
  osImages:
    - openshiftVersion: "4.17"
      version: "417.94.202501071621-0"
      url: "http://ztp-mirror.multicluster-engine.svc.cluster.local:8080/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-live.x86_64.iso"
      rootFSUrl: "http://ztp-mirror.multicluster-engine.svc.cluster.local:8080/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-live-rootfs.x86_64.img"
      cpuArchitecture: x86_64

    - openshiftVersion: "4.16"
      version: "416.94.202501030250-0"
      url: "http://ztp-mirror.multicluster-engine.svc.cluster.local:8080/pub/openshift-v4/x86_64/dependencies/rhcos/4.16/latest/rhcos-live.x86_64.iso"
      rootFSUrl: "http://ztp-mirror.multicluster-engine.svc.cluster.local:8080/pub/openshift-v4/x86_64/dependencies/rhcos/4.16/latest/rhcos-live-rootfs.x86_64.img"
      cpuArchitecture: x86_64

    - openshiftVersion: "4.15"
      version: "415.92.202501080724-0"
      url: "http://ztp-mirror.multicluster-engine.svc.cluster.local:8080/pub/openshift-v4/x86_64/dependencies/rhcos/4.15/latest/rhcos-live.x86_64.iso"
      rootFSUrl: "http://ztp-mirror.multicluster-engine.svc.cluster.local:8080/pub/openshift-v4/x86_64/dependencies/rhcos/4.15/latest/rhcos-live-rootfs.x86_64.img"
      cpuArchitecture: x86_64
```
