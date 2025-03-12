# Installation Examples

For disconnected installations, you're largely going to use the same `install-config.yaml` file that you normally would - just with some extra goodness.

There are common concerns listed right below, and then there are some specific configuration changes you'll need depending on how you're deploying OCP which is found below and in the accompanying YAML manifests.

- [Installation Examples](#installation-examples)
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

## Common/General Disconnected Configuration

No matter what installation method you use, if it starts with an `install-config.yaml` like with IPI/UPI/ABI then you'll find some common configuration needing to be set.

### Pull Secret

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
  - source: registry.redhat.io
    mirrors:
      - registry-redhat-io-ptc.registry.example.com
  - source: registry.connect.redhat.com
    mirrors:
      - registry-connect-redhat-com-ptc.registry.example.com

  # Other handy registries to mirror/proxy cache:
  # GitHub Container Registry - ghcr.io
  # Google Container Registry - gcr.io
  # Kubernetes Container Registry - registry.k8s.io
  # NVIDIA Container Registry - nvcr.io
```

### NTP

A commonly overlooked detail, but critical to successful installations and happy clusters.

By default, RHCOS will use public NTP pools

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
