# OpenShift Virtualization

With OpenShift Virtualization there isn't much that needs to be configured for disconnected environments.

## Additional Trust Bundle

Of course CNV needs to be special so you have to craft different ConfigMaps for additional trusted Root CAs - really could still use the same ConfigMap, but the data key is different, not the standard `ca-bundle.crt` it needs `ca.crt`.  And this has to be defined in the `openshift-cnv` and the `openshift-virtualization-os-images` namespaces.

```yaml
# Yes, you have to create the same named ConfigMap in two places...
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: private-registry-ca
  namespace: openshift-cnv
data:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIH0DCC...
    -----END CERTIFICATE-----
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: private-registry-ca
  namespace: openshift-virtualization-os-images
data:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIH0DCC...
    -----END CERTIFICATE-----
```

## Pull Secrets

In case you're pulling from a private registry, you need to provide it a Pull Secret - but not the normal JSON encoded pull secret format, as access and secret key combinations...

```yaml
# Yes, you have to create the pull secret in two places...
---
kind: Secret
apiVersion: v1
metadata:
  name: private-ps
  namespace: openshift-cnv
stringData:
  accessKeyId: username
  secretKey: password
type: Opaque
---
kind: Secret
apiVersion: v1
metadata:
  name: private-ps
  namespace: openshift-virtualization-os-images
stringData:
  accessKeyId: username
  secretKey: password
type: Opaque
```

## Hyperconverged CR Configuration & Easy OS Image Cron Imports

By default OpenShift Virtualization will try to import the Red Hat supplied base VM images for some included templates, unless you configure your Hyperconverged CR to not do so with `.spec.featureGates.enableCommonBootImageImport: false`.

You could manage the base images for various images manually, just import them as needed for the templates you manage.

You could also create the CDI/DCI/etc configuration for the images to be imported regularly which is useful for base OS images that are frequently updated.

Or - you could just configure the Hyperconverged CR to glue things together for you.

```yaml
---
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
spec:
  storageImport:
    # Disable TLS validation for the private registry
    # Or use the certConfigMap parameter to provide the CA certificate as shown below
    insecureRegistries:
      - quay-ptc.jfrog.lab.kemo.network

  # In disconnected environments you have to specifically tell the operator to use the disconnected registry
  # It doesn't pick it up from the global cluster mirror configuration :)
  # You can source the default values provided by the operator by looking at the .status and copying the values, modifying them as needed, and then applying the changes to the .spec
  # The operator will then apply the changes to the cluster
  # Below is an example of how to configure the operator to use a disconnected registry for the default boot sources to regularly import
  dataImportCronTemplates:
    - metadata:
        annotations:
          cdi.kubevirt.io/storage.bind.immediate.requested: 'true'
        labels:
          kubevirt.io/dynamic-credentials-support: 'true'
        name: centos-stream8-image-cron
      spec:
        garbageCollect: Outdated
        managedDataSource: centos-stream8
        schedule: 30 7/12 * * *
        template:
          metadata: {}
          spec:
            source:
              registry:
                pullMethod: node
                url: 'docker://disconn-harbor.d70.kemo.labs/quay-ptc/containerdisks/centos-stream:8'
                secretRef: private-ps
                certConfigMap: private-registry-ca
            storage:
              resources:
                requests:
                  storage: 30Gi
    - metadata:
        annotations:
          cdi.kubevirt.io/storage.bind.immediate.requested: 'true'
        labels:
          kubevirt.io/dynamic-credentials-support: 'true'
        name: centos-stream9-image-cron
      spec:
        garbageCollect: Outdated
        managedDataSource: centos-stream9
        schedule: 30 7/12 * * *
        template:
          metadata: {}
          spec:
            source:
              registry:
                pullMethod: node
                url: 'docker://disconn-harbor.d70.kemo.labs/quay-ptc/containerdisks/centos-stream:9'
                secretRef: private-ps
                certConfigMap: private-registry-ca
            storage:
              resources:
                requests:
                  storage: 30Gi
    - metadata:
        annotations:
          cdi.kubevirt.io/storage.bind.immediate.requested: 'true'
        labels:
          kubevirt.io/dynamic-credentials-support: 'true'
        name: centos-stream10-image-cron
      spec:
        garbageCollect: Outdated
        managedDataSource: centos-stream10
        schedule: 30 7/12 * * *
        template:
          metadata: {}
          spec:
            source:
              registry:
                pullMethod: node
                url: 'docker://disconn-harbor.d70.kemo.labs/quay-ptc/containerdisks/centos-stream:10'
                secretRef: private-ps
                certConfigMap: private-registry-ca
            storage:
              resources:
                requests:
                  storage: 30Gi
    - metadata:
        annotations:
          cdi.kubevirt.io/storage.bind.immediate.requested: 'true'
        labels:
          kubevirt.io/dynamic-credentials-support: 'true'
        name: fedora40-image-cron
      spec:
        garbageCollect: Outdated
        managedDataSource: fedora
        schedule: 30 7/12 * * *
        template:
          metadata: {}
          spec:
            source:
              registry:
                pullMethod: node
                url: 'docker://disconn-harbor.d70.kemo.labs/quay-ptc/containerdisks/fedora:40'
                secretRef: private-ps
            storage:
              resources:
                requests:
                  storage: 30Gi
    - metadata:
        annotations:
          cdi.kubevirt.io/storage.bind.immediate.requested: 'true'
        labels:
          kubevirt.io/dynamic-credentials-support: 'true'
        name: ubuntu2404-image-cron
      spec:
        garbageCollect: Outdated
        managedDataSource: ubuntu2404
        schedule: 30 7/12 * * *
        template:
          metadata: {}
          spec:
            source:
              registry:
                pullMethod: node
                url: 'docker://disconn-harbor.d70.kemo.labs/quay-ptc/containerdisks/ubuntu:24.04'
                secretRef: private-ps
                certConfigMap: private-registry-ca
            storage:
              resources:
                requests:
                  storage: 30Gi
```