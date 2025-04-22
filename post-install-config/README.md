# Post Installation Cluster Configuration

Once you have an OpenShift cluster deployed, there are a few other extra settings you'll probably want to apply to make sure that everything lines up well.  If you deployed the cluster with network customizations you'll find them likely applied if you inspect them as described below.

Applying many of these configurations in combination can also provide the ability to take a connected cluster and turn it into a disconnected cluster.

- [Cluster-wide Root CA Certs](#cluster-wide-root-ca-certs)
- [Cluster-wide Outbound HTTP Proxy](#cluster-wide-outbound-http-proxy)
- [Updating the Cluster-wide Pull Secret](#updating-the-cluster-wide-pull-secret)
- [Disabling the Insights Operator](#disabling-the-insights-operator)
- [ImageDigestMirrorSets and ImageTagMirrorSets](#imagedigestmirrorsets-and-imagetagmirrorsets)
- [Image CR Configuration](#image-cr-configuration)
- [Enabling the Samples Operator](#enabling-the-samples-operator)

## Cluster-wide Root CA Certs

> [OpenShift Documentation, "Updating the CA Bundle"](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/security_and_compliance/configuring-certificates#ca-bundle-understanding_updating-ca-bundle)

Typically you'll have custom internal Root Certificate Authorities that sign TLS certs for services.  If you provided the certificates during installation, you should find them in the `user-ca-bundle` ConfigMap in the `openshift-config` Namespace under the `ca-bundle.crt` key.  Verify that the contents match what you have for your Root CAs in your PKI: `oc get cm/user-ca-bundle -n openshift-config -o yaml`

If you do not see them in there, you should modify that ConfigMap and set it similar to the following:

```yaml
## Cluster-wide CA bundle for OpenShift
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-ca-bundle
  #namespace: openshift-config
data:
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    MIIH0DCCBbigAwIBAgIUVgbrSwOVQdQJrxeN2XcYdCPyFEMwDQYJKoZIhvcNAQEL
    ... cert text ...
    +wb3mZG781YXVp+JEbeksqL0Dstv6ldNQzawvAL6K7apTiJp
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIGqzCCBJOgAwIBAgIUKMZCYZxHomZOUFLz8j0/ItBY/3cwDQYJKoZIhvcNAQEL
    ... other cert text ...
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... other other cert text ...
    -----END CERTIFICATE-----
```

Once modified, the cluster will refresh it in the appropriate places, often requiring a node reboot.

With the Root CA Certificates in the cluster-wide ConfigMap, you can now create other ConfigMaps with a special label that will inject all the trusted Root CA certificates into it which makes it easy to be used by applications:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: image-additional-trust-bundle
  namespace: openshift-config
  labels:
    # This label will create the .data['ca-bundle.crt'] key with all the system trusted roots, custom and default
    config.openshift.io/inject-trusted-cabundle: 'true'
```

---

## Cluster-wide Outbound HTTP Proxy

> [OpenShift Documentation "Configuring the cluster-wide proxy"](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/networking/enable-cluster-wide-proxy)

Speaking of things that need node reboots - in case you're taking a connected cluster and disconnecting it via an Outbound HTTP Proxy, or are wanting to check the Proxy configuration, you can do that with the Proxy Config CR:

```yaml
---
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  name: cluster
spec:
  httpProxy: http://user:pass@proxy.example.com:3128
  httpsProxy: http://user:pass@proxy.example.com:3128

  # Default things you should probably have in no_proxy
  # .local,.svc,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/23,192.168.0.0/16
  # Make sure to include the domain of your OCP cluster and other internal domains
  # .kemo.network,.kemo.labs
  noProxy: ".local,.svc,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/23,192.168.0.0/16,.kemo.network,.kemo.labs"

  # A reference to the config map in the openshift-config namespace that contains additional CA certificates required for proxying HTTPS connections. Note that the config map must already exist before referencing it here. This field is required unless the proxy’s identity certificate is signed by an authority from the RHCOS trust bundle.
  trustedCA:
    name: 'user-ca-bundle'
```

---

## Updating the Cluster-wide Pull Secret

> [OpenShift Documentation, "Updating the global cluster pull secret"](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/images/managing-images#images-update-global-pull-secret_using-image-pull-secrets)

You may want to update the global pull secret post-install - to do so is rather easy, just edit the `pull-secret` Secret in the `openshift-config` Namespace.  The easiest way to do this is via the Web UI, selecting "Edit Secret" from the "Actions" drop-down will give you a nice form to edit individual registries in the pull secret.

There are also some handy scripts to help will modifying Pull Secrets:

- `scripts/copy-pull-secret-endpoint.sh` - Take in an Pull Secret type K8s/OCP Secret, checks for an original registry endpoint, copies the auth parameters to another new endpoint.
- `scripts/copy-secret.sh` - Copy a Secret, maybe from one namespace to another
- `scripts/join-auths.sh` - Join two pull secret JSON auth files into one
- `scripts/join-ocp-auth-secrets.sh` - Take two separate Pull Secret type K8s/OCP Secrets, joins them into a new Pull Secret type K8s/OCP Secret

So a common workflow would be:

```bash
# Copy the Global Pull Secret to the disconn-tekton namespace
./scripts/copy-secret.sh -i openshift-config/pull-secret -o disconn-tekton/global-pull-secret

# Join the Secret with the one from Pipelines/Internal Image Registry
./scripts/join-ocp-auth-secrets.sh -n disconn-tekton -s global-pull-secret -s pipeline-internal-reg -o combined-reg-secret
```

---

## Disabling the Insights Operator

In a disconnected cluster there's no sense in keeping the telemetry service enabled - go ahead and disable the Insights Operator by modifying its InsightsOperator CR:

```yaml
---
apiVersion: operator.openshift.io/v1
kind: InsightsOperator
metadata:
  name: cluster
spec:
  # Change from Managed to Unmanaged
  managementState: Unmanaged
```

That, combined with removing the `cloud.openshift.com` auth entry from the Cluster-Wide Pull Secret will disable telemetry.

---

## ImageDigestMirrorSets and ImageTagMirrorSets

When you deploy OpenShift in an environment with a private image registry, it will create the ImageDigestMirrorSet for what you have defined during installation.  This is because all the release images are distributed by SHA256 digests, not by named image tags.

Typically in an environment where you're just using an Outbound HTTP Proxy or Pull-through Proxy Cache, you'll see that the Operator CatalogSources are failing to pull.  This is because the Operator Indexes the CatalogSources are referencing are pulled by named tag, eg `:v4.17`.  So to fix this we need to create the ImageTagMirrorSet - same thing as the ImageDigestMirrorSet, just `s/Digest/Tag/g` really, the format is the same otherwise.

```yaml
# ImageDigestMirrorSet
---
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
    name: global
spec:
  imageDigestMirrors:
    # Mandatory for OpenShift
    - source: quay.io/openshift-release-dev/ocp-release
      mirrors:
        - disconn-harbor.d70.kemo.labs/quay-ptc/openshift-release-dev/ocp-release
    - source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
      mirrors:      
        - disconn-harbor.d70.kemo.labs/quay-ptc/openshift-release-dev/ocp-v4.0-art-dev

    # Optional for other registries
    - source: quay.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/quay-ptc
    - source: registry.redhat.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/registry-redhat-io-ptc
    - source: registry.connect.redhat.com
      mirrors:
        - disconn-harbor.d70.kemo.labs/registry-connect-redhat-com-ptc
    - source: ghcr.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/ghcr-ptc
```

```yaml
# ImageTagMirrorSet
---
apiVersion: config.openshift.io/v1
kind: ImageTagMirrorSet
metadata:
    name: global
spec:
  imageTagMirrors:
    # Mandatory for OpenShift
    - source: quay.io/openshift-release-dev/ocp-release
      mirrors:
        - disconn-harbor.d70.kemo.labs/quay-ptc/openshift-release-dev/ocp-release
    - source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
      mirrors:      
        - disconn-harbor.d70.kemo.labs/quay-ptc/openshift-release-dev/ocp-v4.0-art-dev

    # Optional for other registries
    - source: quay.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/quay-ptc
    - source: registry.redhat.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/registry-redhat-io-ptc
    - source: registry.connect.redhat.com
      mirrors:
        - disconn-harbor.d70.kemo.labs/registry-connect-redhat-com-ptc
    - source: ghcr.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/ghcr-ptc
```

With those created, the MachineConfig Operator will take it and embed it into one of the core managed MachineConfigs.  What's baked into it is the configuration of the `/etc/containers/registries.conf` file.  If you enter a debug terminal on one of the nodes and enter the host filesystem with `chroot /host` you can check the contents of that file to see how the values are templated into standard Linux Container Runtime Interface configuration.

---

## Image CR Configuration

The cluster has different mechanisms to control how images are pulled - you can block registries, specifically only registries, set insecure registries, etc.  This is all configured in the Image CR.

You also need to set some configuration here for registries you're pulling from that are signed by custom Root CA certificates.  These definitions are used for ImageStreams, the OpenShift Update Service, and a couple of other places.  Not required for core cluster image pulling functionality but good to configure nonetheless.

To define Root CA certificates, you have to create a ConfigMap.  This ConfigMap needs to have keys that are named for the hostname of the registry.  If you're using a non-443 port for the registry, append it to the hostname with two dots to separate it, eg `registry.example.com:5000` would be `registry.example.com..5000`.

When configuring the Root CA for the registry that hosts the OpenShift Releases served by the OpenShift Update Service there is an `updateservice-registry` key that is used - if it's going to be the same registry as one you're already using then it's a good idea to go ahead and configure that at the same time too.

```yaml
# Root CA definitions for use by the config/Image CR
# Each image registry URL should have a corresponding entry in this ConfigMap
# with the registry URL as the key and the CA certificate as the value.
# If there is a port for the registry, use two dots to separate the registry hostname and the port.
# For example, if the registry URL is registry.example.com:5000, the key should be registry.example.com..5000
# The updateservice-registry entry is used for the OpenShift Update Service
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: image-ca-bundle
  namespace: openshift-config
data:
  # updateservice-registry is for the registry hosting OSUS Releases
  updateservice-registry: |
    -----BEGIN CERTIFICATE-----
    MIIH0DCCBbigAwIBAgIUVgbrSwOVQdQJrxeN2XcYdCPyFEMwDQYJKoZIhvcNAQEL
    ... cert text here ...
    +wb3mZG781YXVp+JEbeksqL0Dstv6ldNQzawvAL6K7apTiJp
    -----END CERTIFICATE-----
  disconn-harbor.d70.kemo.labs: |
    -----BEGIN CERTIFICATE-----
    ... cert text here ...
    -----END CERTIFICATE-----
  quay-ptc.jfrog.lab.kemo.network: |
    -----BEGIN CERTIFICATE-----
    ... cert text here ...
    -----END CERTIFICATE-----
  registry-redhat-ptc.jfrog.lab.kemo.network: |
    -----BEGIN CERTIFICATE-----
    ... cert text here ...
    -----END CERTIFICATE-----
```

With that ConfigMap created, you can now configure the Image CR with it and any other configuration you want:

```yaml
---
apiVersion: config.openshift.io/v1
kind: Image
metadata:
  name: cluster
spec:
  # additionalTrustedCA is a reference to a ConfigMap containing additional CAs that should be trusted during imagestream import, pod image pull, build image pull, and imageregistry pullthrough.
  # The namespace for this config map is openshift-config.
  additionalTrustedCA:
    name: image-ca-bundle
  
  # Optional configuration...

  # allowedRegistriesForImport limits the container image registries that normal users may import images from. Set this list to the registries that you trust to contain valid Docker images and that you want applications to be able to import from.
  # Users with permission to create Images or ImageStreamMappings via the API are not affected by this policy - typically only administrators or system integrations will have those permissions.
  allowedRegistriesForImport:
    - image-registry.openshift-image-registry.svc:5000
    - default-route-openshift-image-registry.apps.endurance-sno.d70.lab.kemo.network
    - disconn-harbor.d70.kemo.labs
    - quay-ptc.jfrog.lab.kemo.network 
    - registry-redhat-ptc.jfrog.lab.kemo.network
    - nexus.kemo.labs:5000

  registrySources:
    # allowedRegistries are the only registries permitted for image pull and push actions. All other registries are denied. 
    # Only one of blockedRegistries or allowedRegistries may be set.
    allowedRegistries:
      - image-registry.openshift-image-registry.svc:5000
      - default-route-openshift-image-registry.apps.endurance-sno.d70.lab.kemo.network
      - disconn-harbor.d70.kemo.labs
      - quay-ptc.jfrog.lab.kemo.network 
      - registry-redhat-ptc.jfrog.lab.kemo.network
      - nexus.kemo.labs:5000

    # blockedRegistries cannot be used for image pull and push actions. All other registries are permitted. 
    # Only one of BlockedRegistries or AllowedRegistries may be set.
    blockedRegistries:
      - docker.io

    # containerRuntimeSearchRegistries are registries that will be searched when pulling images that do not have fully qualified domains in their pull specs.
    # Registries will be searched in the order provided in the list.
    # Note: this search list only works with the container runtime, i.e CRI-O. Will NOT work with builds or imagestream imports.
    containerRuntimeSearchRegistries:
      - image-registry.openshift-image-registry.svc:5000
      - disconn-harbor.d70.kemo.labs

    # insecureRegistries are registries which do not have a valid TLS certificates or only support HTTP connections.
    insecureRegistries:
      - nexus.kemo.labs:5000
```

---

## Enabling the Samples Operator

> [OpenShift Documentation, "Configuring image streams for a disconnected cluster"](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/postinstallation_configuration/post-install-image-config#installation-images-samples-disconnected-mirroring-assist_post-install-image-config)
https://access.redhat.com/solutions/5067531

If your cluster has network customizations that are not providing a fully-connected cluster then the Samples ClusterOperator will be in a disabled state.  Now, most times this isn't a big deal, but you may want the Quick Starts and Samples provided as ImageStreams in the Developer Console - they are handy if you want to do S2I things.

> Note: This requires the Internal Image Registry

1. Set the Samples Operator's Config CR to a Managed state to start it rolling out:

```yaml
apiVersion: samples.operator.openshift.io/v1
kind: Config
metadata:
  name: cluster
spec:
  managementState: Managed
  # ...
```

This should enable the Samples ClusterOperator and produce more errors when the ImageStreams fail to import.  This is expected at this point.

2. If you need to manually mirror images, follow the next few steps, otherwise skip to step 6.
3. Log into your terminal, get the list of images the ImageStreams are trying to pull: `for i in `oc get is -n openshift --no-headers | awk '{print $1}'`; do oc get is $i -n openshift -o json | jq .spec.tags[].from.name | grep registry.redhat.io | sed -e 's/"//g' | cut -d"/" -f2-; done | tee imagelist.txt`
4. Make sure you're authenticated to both the Red Hat Registry and your Private Registry.
5. Mirror the containers for the ImageStreams: `for i in `cat imagelist.txt`; do oc image mirror registry.redhat.io/$i ${MIRROR_ADDR_URL}/registry-redhat-io/$i; done`
6. Create a ConfigMap with the registry Root CA cert:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: image-ca-bundle
  namespace: openshift-config
data:
  # Create one key per registry URI
  # Use double dots to specify a non-443 port
  # eg disconn-harbor.d70.kemo.labs..5000: |
  disconn-harbor.d70.kemo.labs: |
    -----BEGIN CERTIFICATE-----
    MIIH0DCCBbigAwIBAgIUVgbrSwOVQdQJrxeN2XcYdCPyFEMwDQYJKoZIhvcNAQEL
    ...
    ...
    +wb3mZG781YXVp+JEbeksqL0Dstv6ldNQzawvAL6K7apTiJp
    -----END CERTIFICATE-----
```

7. Set the Image Config CR to use the ConfigMap:

```yaml
---
apiVersion: config.openshift.io/v1
kind: Image
metadata:
  name: cluster
spec:
  additionalTrustedCA:
    name: image-ca-bundle
```

8. Configure the Samples ClusterOperator Config to point to the mirror registry:

```yaml
---
apiVersion: samples.operator.openshift.io/v1
kind: Config
metadata:
  name: cluster
spec:
  samplesRegistry: disconn-harbor.d70.kemo.labs/registry-redhat-io
```

9. The ImageStreams should have their Warning messages resolved shortly after they're pulled, and you should be able to use the provided Samples in the Developer Console now.