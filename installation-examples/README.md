# Installation Examples

For disconnected installations, you're largely going to use the same `install-config.yaml` file that you normally would - just with some extra goodness.

There are common concerns listed right below, and then there are some specific configuration changes you'll need depending on how you're deploying OCP which is found below and in the accompanying YAML manifests.

- [Common/General Disconnected Configuration](#commongeneral-disconnected-configuration)
  - [Pull Secret](#pull-secret)
  - [Additional Root CA Certificates](#additional-root-ca-certificates)
  - [Outbound HTTP Proxy](#outbound-http-proxy)
  - [Container Registry Mirrors](#container-registry-mirrors)
  - [NTP](#ntp)
- [Per Provider - vSphere IPI/UPI](#per-provider---vsphere-ipiupi)
- [Per Provider - OpenStack IPI/UPI](#per-provider---openstack-ipiupi)
- [Per Provider - Bare Metal IPI/UPI](#per-provider---bare-metal-ipiupi)
- [Per Provider - Nutanix IPI/UPI](#per-provider---nutanix-ipiupi)
- [Per Provider - Agent Based Installer](#per-provider---agent-based-installer)
- [Hosted Control Plane Examples](#hosted-control-plane-examples)
  - [Additional Trust Bundle](#additional-trust-bundle)
  - [Container Mirror Configuration](#container-mirror-configuration)
  - [Pull Secret \& Release Images](#pull-secret--release-images)
  - [NTP](#ntp-1)
  - [Outbound Proxy Configuration](#outbound-proxy-configuration)
- [ACM Assisted Service/Hive Examples](#acm-assisted-servicehive-examples)
  - [AgentClusterInstall - Proxy Configuration](#agentclusterinstall---proxy-configuration)
  - [ClusterDeployment - Additional Trust Bundle](#clusterdeployment---additional-trust-bundle)
  - [ClusterDeployment - Pull Secret](#clusterdeployment---pull-secret)
  - [InfraEnv - Pull Secret](#infraenv---pull-secret)
  - [InfraEnv - Outbound Proxy](#infraenv---outbound-proxy)
  - [InfraEnv - NTP](#infraenv---ntp)

## Common/General Disconnected Configuration

No matter what installation method you use, if it starts with an `install-config.yaml` like with IPI/UPI/ABI then you'll find some common configuration needing to be set.

### Pull Secret

> For IPI/UPI/ABI

Not much to this - make sure your combined pull secret has the credentials provided by Red Hat as well as the ones needed to access any private container image registries.

Even though we're not communicating with Red Hat Registries and Quay, those credentials are still needed to align configuration, even if they're largely unused and could even be blank.

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

# Just make sure the pull secret has all the registries needed
pullSecret: '{"auths":{"registry.example.com":{"auth":"bigLongBase64String"}, "quay.io":{"auth":"bigLongBase64StringFromRedHatPullSecret"}, "yada.yada.com":{"auth":"bigLongBase64String"}}}'
```

You can find a script in [./scripts/join-auths.sh](../scripts/join-auths.sh) that can take two pull secret files and join them for you.

### Additional Root CA Certificates

> For IPI/UPI/ABI

In case your container image registry/proxy/etc service has a TLS/SSL certificate that is signed by a custom/internal Root CA that is not part of the standard `ca-certificates` Linux system package, you'll need to provide the Root CA to the installer to trust.

> You may also need to provide any Intermediate CAs on the chain if the leaf certificate does not provide them.

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

# additionalTrustBundlePolicy - This can be set to either Always or ProxyOnly.
# It's suggested to provide all your Root CAs, including any separate ones for an Outbound Proxy - and set to Always.
additionalTrustBundlePolicy: Always

# additionalTrustBundle - Just a big block of PEM base64 encoded certificates.  Note the indention.
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  MIIDGzCCAgOgAwIBAgIQIiia9v4QpyL2ar7kW4K2cDANBgkqhkiG9w0BAQsFADAm
  MSQwIgYDVQQDExtLZW1vIExhYnMgU21hbGxTdGVwIFJvb3QgQ0EwHhcNMjIwNDAz
  MjAzNDA5WhcNMzIwMzMxMjAzNDA5WjAmMSQwIgYDVQQDExtLZW1vIExhYnMgU21h
  bGxTdGVwIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDF
  w9Y9/ScdF8bmgElmQQQFJku033PkOMtPOCakAaPCly1reqHm8r3Mjhjuqi8HiC94
  NQ+jWYRFzAGyMUZfR9PaCnN4EsVRjX1KAvttX4eRXgAo8SsIb9ExKHVSVDoBCm62
  /FpVYE24bgUcN5gqnp7lMdSlW69ArnpSnLOkQCGDXknSEBCGUdpz8jdehqAyXoFo
  yedC9oAxvisEQ3SjyMQDqKo7XNS2VEODozGp0bNcym5461VHeIVulo1/8/kPfEkv
  Zjr7ZzGjRiEn1a0wrbDtdTG5VSobGQW/I9VIgbXp0pTUUzurIAlOh+LzvnNwVKIv
  XFkJfutEGrAxFDYX6K9xAgMBAAGjRTBDMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
  Af8ECDAGAQH/AgEBMB0GA1UdDgQWBBSuSpXt1rL5wa2CyYFfchCD3ZCzSjANBgkq
  hkiG9w0BAQsFAAOCAQEAe6Prprq70SLis/5LJVl8pC+MgPa/ICukJ1O3C6Jn4w6y
  GGCBwa26SAw49J54qizQPbQdks0px0fQCIzbKlVA44lfq6VwSpXrM/VgesGB4vez
  vfdDBvJwnc5/E93NxtxinbVvNps7xfa2kW22xu2GZoOueAJr3gcG8ZQMZc7oMY4a
  7OaqWH9OyUhax2Odv+37Its5PjBbr7vHabzw6F6849Lx1vDwlpg0dqCFVMSKvm4l
  KK4oFUbZw0+cLmAlOYHrw5QIHqAGT7p8Cew5zR/fuuKJx2yiKP/tsz6E1OMejN9q
  g/IdSjffp7OClDHFa3nuXzsKk87O3eTr4fzKALVpqQ==
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MII...other Root CA cert
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MII...other Root CA cert or intermediate
  -----END CERTIFICATE-----
```

### Outbound HTTP Proxy

> For IPI/UPI/ABI

In case you're just accessing things through an Outbound HTTP Proxy, you'll need to pass along that configuration as well:

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

# Optional Outbound Proxy Configuration
proxy:
  http_proxy: http://username:password@proxy.kemo.labs:3129
  https_proxy: http://username:password@proxy.kemo.labs:3129
  # Default things you should probably have in no_proxy
  # .local,.svc,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/23,192.168.0.0/16
  # Make sure to include the domain of your OCP cluster
  # .kemo.network,.kemo.labs
  no_proxy: ".local,.svc,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/23,192.168.0.0/16,.kemo.network,.kemo.labs"
```

### Container Registry Mirrors

> For IPI/UPI/ABI

When using a private container image registry, you'll need to tell the OpenShift Installer where to pull images from instead of the default sources.

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

imageContentSources:
  # Must have a direct reference to both the openshift-release-dev/ocp-release and openshift-release-dev/ocp-v4.0-art-dev paths
  # These two are the only ones required to complete an installation of OpenShift
  - source: quay.io/openshift-release-dev/ocp-release
    mirrors:
      # Example for custom non-related path
      - registry.example.com/ocp-releases/ocp-release

  - source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
    mirrors:
      # Example for custom non-related path
      - registry.example.com/ocp-releases/ocp-v4.0-art-dev
      # Example for a sub-path Pull-Through/Proxy Cache
      - registry.example.com/quay-ptc/openshift-release-dev/ocp-v4.0-art-dev
      # Example for a sub-domain Pull-Through/Proxy Cache
      - quay-ptc.registry.example.com/openshift-release-dev/ocp-v4.0-art-dev
    
  # Add any additional alternative mirrors you want to define
  - source: quay.io
    mirrors:
      # Example for sub-domain pull-through cache
      - quay-ptc.registry.example.com
  # Used for Red Hat created workloads
  - source: registry.redhat.io
    mirrors:
      - registry-redhat-io-ptc.registry.example.com
  # Used for certified/marketplace workloads
  - source: registry.connect.redhat.com
    mirrors:
      - registry-connect-redhat-com-ptc.registry.example.com

  # Other handy registries to mirror/proxy cache:
  # Public Red Hat Registry - registry.access.redhat.com
  # GitHub Container Registry - ghcr.io
  # Google Container Registry - gcr.io
  # Kubernetes Container Registry - registry.k8s.io
  # NVIDIA Container Registry - nvcr.io
  # Docker Hub - docker.io
```

### NTP

> For non-baremetal IPI/UPI - see below for ABI, Baremetal IPI/UPI, or HCP

A commonly overlooked detail, but critical to successful installations and happy clusters.

By default, RHCOS will use public NTP pools.

In case your NTP is not provided to your infrastructure via DHCP, you'll need to craft a MachineConfig and provide it as an additional manifest to the IPI/UPI installation.  Additional details can be found here: https://docs.openshift.com/container-platform/4.18/installing/installing_bare_metal/upi/installing-restricted-networks-bare-metal.html#installation-special-config-chrony_installing-restricted-networks-bare-metal

tl;dr is:

```yaml
variant: openshift
version: 4.18.0
metadata:
  name: 99-worker-chrony 
  labels:
    machineconfiguration.openshift.io/role: worker 
storage:
  files:
  - path: /etc/chrony.conf
    mode: 0644 
    overwrite: true
    contents:
      inline: |
        pool 0.rhel.pool.ntp.org iburst 
        driftfile /var/lib/chrony/drift
        makestep 1.0 3
        rtcsync
        logdir /var/log/chrony
```

Modify that file, then run `butane 99-worker-chrony.bu -o 99-worker-chrony.yaml`.  Repeat for master nodes.

You can then use the generated MachineConfig YAML post-install with an `oc apply -f 99-worker-chrony.yaml`

For use during initial installation, add the MachineConfig file to the `<installation_directory>/openshift` directory, and then continue to create the cluster.

For non-IPI/UPI Installation, there are other mechanisms to specify NTP servers that are provided in their relevant sections.

---

## Per Provider - vSphere IPI/UPI

When deploying to vSphere, you'll need to provide some additional configuration to point to wherever you have the RHCOS OVA hosted.

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

platform:
  vsphere:
    # .. your other vSphere config ...
    clusterOSImage: http://mirror.example.com/pub/rhcos/rhcos-vmware.x86_64.ova?sha256=ffebbd68e8a1f2a245ca19522c16c86f67f9ac8e4e0c1f0a812b068b16f7265d
    # .. your other vSphere config ...
```

You can generate the SHA256 sum by running `sha256sum rhcos-vmware.x86_64.ova`

---

## Per Provider - OpenStack IPI/UPI

When deploying to OpenStack, you'll need to provide some additional configuration to point to wherever you have the RHCOS QCOW2 hosted.  You'll also need to upload the QCOW2 file to the OpenStack cluster.

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

platform:
  openstack:
    # .. your other OpenStack config ...
    clusterOSImage: http://mirror.example.com/pub/rhcos/rhcos-openstack.x86_64.qcow2.gz?sha256=ffebbd68e8a1f2a245ca19522c16c86f67f9ac8e4e0c1f0a812b068b16f7265d
    # .. your other OpenStack config ...
```

You can generate the SHA256 sum by running `sha256sum rhcos-openstack.x86_64.qcow2.gz`

---

## Per Provider - Bare Metal IPI/UPI

*plz dont do bare metal IPI/UPI, just use the Agent Based Installer plzplzplz*

In case you need to, you can provide the boot artifacts for Bare Metal IPI with the following config:

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

platform:
  baremetal:
    # .. your other OpenStack config ...
    # https://docs.openshift.com/container-platform/4.18/installing/installing_bare_metal/ipi/ipi-install-installation-workflow.html#ipi-install-creating-an-rhcos-images-cache_ipi-install-installation-workflow
    # bootstrapOSImage: A URL to override the default operating system image for the bootstrap node.
    # The URL must contain a SHA-256 hash of the image. For example: https://mirror.openshift.com/rhcos-<version>-qemu.qcow2.gz?sha256=<uncompressed_sha256>;
    bootstrapOSImage: http://mirror.example.com/pub/rhcos/rhcos-qemu.x86_64.qcow2.gz?sha256=ffebbd68e8a1f2a245ca19522c16c86f67f9ac8e4e0c1f0a812b068b16f7265d
    # .. your other OpenStack config ...
```

You can generate the SHA256 sum by running `sha256sum rhcos-qemu.x86_64.qcow2.gz`

It is no longer needed to provide a `.platform.baremetal.clusterOSImage` parameter, the machine assets are part of the containerized release payload.

To provide additional NTP servers without making Butane/MachineConfigs, you can provide it as additional configuration in the baremetal provider configuration:

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

platform:
  baremetal:
    additionalNTPServers:
      - <ip_address_or_domain_name>
```

---

## Per Provider - Nutanix IPI/UPI

When deploying to Nutanix, you'll need to provide some additional configuration to point to wherever you have the RHCOS QCOW2 hosted.

```yaml
# install-config.yaml
---
apiVersion: v1

# ... Various config things

platform:
  nutanix:
    # .. your other Nutanix config ...
    clusterOSImage: http://mirror.example.com/pub/rhcos/rhcos-nutanix.x86_64.qcow2?sha256=ffebbd68e8a1f2a245ca19522c16c86f67f9ac8e4e0c1f0a812b068b16f7265d
    # .. your other Nutanix config ...
```

You can generate the SHA256 sum by running `sha256sum rhcos-nutanix.x86_64.qcow2`

---

## Per Provider - Agent Based Installer

With the Agent Based Installer, the RHCOS assets are pulled from a container image when you run the `openshift-install agent` commands.

Make sure you have the various common `install-config.yaml` parameters applied (Pull Secret, Additional Root CAs, Proxy, Container Mirrors, etc).

To define additional NTP servers, add them into the `agent-config.yaml` file that defines the node topology:

```yaml
# agent-config.yaml
---
apiVersion: v1alpha1
kind: AgentConfig
# .. your other AgentConfig things ...

additionalNTPSources:
  - ntp.example.com

# .. your other AgentConfig things ...
```

Once the ISO is generated, you could automate bare metal system booting via Redfish like with this: https://github.com/kenmoini/ansible-redfish

---

## Hosted Control Plane Examples

In case you're not using IPI/UPI/ABI and you're using the ever-wonderful goodness that is Hosted Control Planes, then you have a whole totally different set of YAML manifests to modify for disconnected deployments.

Many of the cluster-level configuration parameters such as MachineConfigs are passed to HostedClusters via ConfigMaps and referenced in the NodePool CRs:

```yaml
---
apiVersion: hypershift.openshift.io/v1beta1
kind: NodePool
metadata:
  name: 'kiddie-pool'
  namespace: 'clusters'
spec:
  config:
    - name: 'config-imagemirrors'
    - name: 'img-tag-override'
    - name: '999-chronyd-config'
  # ... other NodePool config ...
```

### Additional Trust Bundle

To define additional Root CA Certs for the HCP cluster to trust, add them in a ConfigMap - there is the general `ca-bundle.crt` key for system-wide trusted certs, and then individual ones for the Image CR, you can put them all in a single ConfigMap like so:

```yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: user-ca-bundle
  namespace: 'clusters'
  #labels:
  #  config.openshift.io/inject-trusted-cabundle: 'true'
data:
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    MIIH....
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIH....other root cert
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIH....third root cert
    -----END CERTIFICATE-----
  quay-ptc.jfrog.lab.kemo.network: |
    -----BEGIN CERTIFICATE-----
    MIIH....
    -----END CERTIFICATE-----
  registry-redhat-ptc.jfrog.lab.kemo.network: |
    -----BEGIN CERTIFICATE-----
    MIIH....
    -----END CERTIFICATE-----
```

Then reference that ConfigMap in the HostedCluster CR:

```yaml
---
apiVersion: hypershift.openshift.io/v1beta1
kind: HostedCluster
metadata:
  name: 'hypershift-virt'
  namespace: 'clusters'
  labels:
    "cluster.open-cluster-management.io/clusterset": 'default'
spec:
  # ========================================================================================
  # Additional Trust Bundle Configuration
  # ========================================================================================
  # .spec.additionalTrustBundle applies extra root CAs to the HCP nodes and cluster services
  additionalTrustBundle:
    name: user-ca-bundle
  # .spec.configuration.image.additionalTrustedCA applies trusted Roots for image registries
  configuration:
    image:
      additionalTrustedCA:
        name: user-ca-bundle
```

### Container Mirror Configuration

To define your image registry mirrors, you more or less just put an IDMS/ITMS objects into a ConfigMap and call it a day - pretty much like you would do for any other MachineConfig for HCP:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-imagemirrors
data:
  config: |
    apiVersion: config.openshift.io/v1
    kind: ImageDigestMirrorSet
    metadata:
      name: image-digest-mirror
    spec:
      imageDigestMirrors:
        # Remember, the ocp-release and ocp-v4.0-art-dev definitions are required
        - mirrors:
            - quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-release
          source: quay.io/openshift-release-dev/ocp-release
        - mirrors:
            - quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-v4.0-art-dev
          source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
        - mirrors:
            - quay-ptc.jfrog.lab.kemo.network
          source: quay.io
        - mirrors:
            - registry-redhat-ptc.jfrog.lab.kemo.network
          source: registry.redhat.io
        - mirrors:
            - registry-connect-redhat-ptc.jfrog.lab.kemo.network
          source: registry.connect.redhat.com
        - mirrors:
            - registry-access-redhat-ptc.jfrog.lab.kemo.network
          source: registry.access.redhat.com
```

...and another place to add the mirrors is in the HostedCluster CR:

```yaml
---
apiVersion: hypershift.openshift.io/v1beta1
kind: HostedCluster
metadata:
  name: 'hypershift-virt'
  namespace: 'clusters'
  labels:
    "cluster.open-cluster-management.io/clusterset": 'default'
spec:
  # ========================================================================================
  # Disconnected/Private Registry Configuration
  # ========================================================================================
  imageContentSources:
  - source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
    mirrors:
      - quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-v4.0-art-dev
  - source: quay.io/openshift-release-dev/ocp-release
    mirrors:
      - quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-release
  - source: quay.io
    mirrors:
      - quay-ptc.jfrog.lab.kemo.network
  - source: registry.redhat.io
    mirrors:
      - registry-redhat-ptc.jfrog.lab.kemo.network
  - source: registry.connect.redhat.com
    mirrors:
      - registry-connect-redhat-ptc.jfrog.lab.kemo.network
```

### Pull Secret & Release Images

For HCP clusters to start from a mirror registry, the release image has to be defined in the HostedCluster CR:

```yaml
---
apiVersion: hypershift.openshift.io/v1beta1
kind: HostedCluster
metadata:
  name: 'hypershift-virt'
  namespace: 'clusters'
  labels:
    "cluster.open-cluster-management.io/clusterset": 'default'
spec:
  # OpenShift Release Image location
  release:
    # Disconnected/Mirror registry
    image: quay-ptc.jfrog.lab.kemo.network/openshift-release-dev/ocp-release:4.17.12-x86_64
  # Make sure the Pull Secret has access to all registries, Red Hat and private
  pullSecret:
    name: pull-secret
```

### NTP

Much like other install methods, you'll probably need to override the default public RHEL NTP pools if you're deploying HCP.  Guess what?  This is also another MachineConfig stuffed in a ConfigMap!

```yaml
# pool ntp.kemo.labs iburst
# driftfile /var/lib/chrony/drift
# makestep 1.0 3
# rtcsync
# logdir /var/log/chrony

# cG9vbCBudHAua2Vtby5sYWJzIGlidXJzdApkcmlmdGZpbGUgL3Zhci9saWIvY2hyb255L2RyaWZ0Cm1ha2VzdGVwIDEuMCAzCnJ0Y3N5bmMKbG9nZGlyIC92YXIvbG9nL2Nocm9ueQo=

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: 999-chronyd-config
  namespace: clusters
data:
  config: |
    apiVersion: machineconfiguration.openshift.io/v1
    kind: MachineConfig
    metadata:
      labels:
        machineconfiguration.openshift.io/role: worker
      name: 999-chronyd-config
    spec:
      config:
        ignition:
          version: 3.2.0
        storage:
          files:
          - contents:
              source: data:text/plain;charset=utf-8;base64,cG9vbCBudHAua2Vtby5sYWJzIGlidXJzdApkcmlmdGZpbGUgL3Zhci9saWIvY2hyb255L2RyaWZ0Cm1ha2VzdGVwIDEuMCAzCnJ0Y3N5bmMKbG9nZGlyIC92YXIvbG9nL2Nocm9ueQo=
            mode: 420
            overwrite: true
            path: /etc/chrony.conf
```

### Outbound Proxy Configuration

If you're using an Outbound HTTP Proxy for installation, you define that in the HostedCluster CR:

```yaml
---
apiVersion: hypershift.openshift.io/v1beta1
kind: HostedCluster
metadata:
  name: 'hypershift-virt'
  namespace: 'clusters'
  labels:
    "cluster.open-cluster-management.io/clusterset": 'default'
spec:
  # ========================================================================================
  # Outbound Proxy Configuration
  # ========================================================================================
  proxy:
    httpProxy: http://proxy.kemo.labs:3128
    httpsProxy: http://proxy.kemo.labs:3128
    noProxy: '.kemo.labs,.kemo.network,.local,.svc,localhost,127.0.0.1,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8'
```

## ACM Assisted Service/Hive Examples

### AgentClusterInstall - Proxy Configuration

When using the Host Inventory AgentClusterInstall, you'll need to define an outbound proxy if that's how you rock and roll:

```yaml
---
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: cluster-name
spec:
  proxy:
    httpProxy: http://proxy.kemo.labs:3129
    httpsProxy: http://proxy.kemo.labs:3129
    noProxy: '.kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local'
```

### ClusterDeployment - Additional Trust Bundle

When using Host Inventory deployments, your ClusterDeployment needs to be configured for extra Root CAs in the typical ConfigMap:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: root-ca-in-a-secret-lol
stringData:
  tls-ca-bundle.pem: |
    -----BEGIN CERTIFICATE-----
    MII...
    -----END CERTIFICATE-----
---
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: cluster-name
spec:
  certificateBundles:
    - name: root-ca-in-a-secret-lol
      certificateSecretRef:
        name: root-ca-in-a-secret-lol
```

### ClusterDeployment - Pull Secret

The ClusterDeployment holds Pull Secret configuration that's used by the nodes when they boot.

```yaml
---
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: cluster-name
spec:
  pullSecretRef:
    name: private-pull-secret
```

### InfraEnv - Pull Secret

The InfraEnv holds Pull Secret configuration that's used by the nodes when they boot.

```yaml
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: cluster-name
spec:
  pullSecretRef:
    name: private-pull-secret
```

### InfraEnv - Outbound Proxy

The InfraEnv has additional Outbound Proxy configuration that's used by the nodes when they boot.

```yaml
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: cluster-name
spec:
  proxy:
    httpProxy: http://proxy.kemo.labs:3129
    httpsProxy: http://proxy.kemo.labs:3129
    noProxy: '.kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local'
```

### InfraEnv - NTP

The InfraEnv can override what NTP sources are used for the systems at boot/install.

```yaml
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: cluster-name
spec:
  additionalNTPSources:
    - ntp.kemo.com
```