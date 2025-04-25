# Operator Management

Installing OpenShift from a mirror is easy - managing the hundreds of Operators for OpenShift is a bit more involved, but hopefully this makes things easier.

*Speaking of easy...*

## How to Not Do Any of This

If you have a container image registry already deployed, and if it's able to access the Internet and be reached by private networks, then you can likely configure it as a Pull-through or Proxy Cache.  Image registries such as JFrog Artifactory, Harbor, Nexus, etc can function as this sort of image broker.

What this does is make it to where when you request `quay.io/kenmoini/banana-phone` via your private container image registry - say at `harbor.example.com/quay-cache/kenmoini/banana-phone` - the image registry will go pull it down locally to itself, then serve it to the client requesting the image.

This means that any external images can be transparently pulled in without intervention, while also giving you control over what is brought in with the respective policy engines these registries have.

> If you can do this, you should, otherwise you're going to have a lot more work to do.

- [Configure Harbor to work as a Pull-through/Proxy Cache](./pullthrough-proxy-cache-harbor.md)
- [Configure JFrog to work as a Pull-through/Proxy Cache](./pullthrough-proxy-cache-jfrog.md)

Note that JFrog may not be a perfect pull-through/proxy cache - when being used for OpenShift releases via OSUS, it will hit a limit on the number of image tags that JFrog can proxy: https://jfrog.atlassian.net/browse/RTFACT-18971

---

## Operators 101

- Hi, I'm Ken.
- I made an **Operator**.
- That Operator has an **Operator Controller**, and maybe some other controllers or various Pods that are also deployed - like how deploying ACM will deploy a bunch of other Operator controllers.  These are all images that need to be built and defined in the metadata.
- Once the Operator is all built, I build an **Operator Bundle**.  This Bundle has the channel/version distribution and metadata for the various releases of the Operator. 
- I make **another Operator**.  I build it, its images, and its own Operator Bundle.
- I take both of these Operator Bundles, and add them to an **Operator Index**.
- OpenShift comes with four Operator Indexes: redhat-operators, marketplace-operators, certified-operators, and community-operators.
- These Operator Indexes are loaded into an OpenShift cluster via **CatalogSource** Custom Resources.
- The OpenShift cluster will sync down the Operator Indexes defined in the CatalogSources every so often (10min default)
- The process of doing so involves pulling down the Operator Index image, accessing it via GRPC, and pulling the list of Bundles in the Index.
- The extracted Bundles are represented as **PackageManifest** CRs in the cluster.  The PackageManifests are what you see as cards in the OperatorHub.
- A **Subscription** CR is created to install an Operator - it defines the named PackageManifest of the Operator, the CatalogSource it's from (since the same named Operator/Bundle can be distributed to multiple Indexes/CatalogSources), and what channel/version to install, and how to handle updates (automatic/manual).
- Depending on the cluster/namespace scope of the Operator, an **OperatorGroup** CR is defined.
- With the Subscription and OperatorGroup applied to a Namespace, OLM will create an **InstallPlan** CR for a specific version and the application of its CRDs and controllers.
- When that InstallPlan is approved, or a new InstallPlan for an upgrade is created, OLM will manage the **ClusterServiceVersion** CRs for the specific versions of an instaled Operator.
- The ClusterServiceVersions define what API CustomResourceDefinitions are exposed by the Operator (and a lot of other metadata)
- When creating an **Instance of an Operator (an Operand)**, the Operator controllers deployed by the CSVs will listen for mutations of those Operands and do whatever it is that they do.

More in-depth information can be found here: https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html-single/operators/index

---

## Operators with Outbound Proxies

Not all Operators are made the same.  Some will use the cluster-wide Outbound HTTP Proxy, some will not.  For the latter, you may need to set the configuration on the Subscription CR used to deploy the Operator:

```yaml
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: some-operator
  namespace: openshift-operators
spec:
  config:
    env:
    - name: HTTP_PROXY
      value: http://proxy.kemo.labs:3129
    - name: HTTPS_PROXY
      value: http://proxy.kemo.labs:3129
    - name: NO_PROXY
      value: '.kemo.labs,.kemo.network,.local,.svc,localhost,127.0.0.1,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8'
```

Sometimes that won't be inherited by the subsequent Operator resources deployed, and you may need to look for additional places to configure Outbound Proxy settings.

---

## Operators and Additional Root CA Trust Bundles

In case your Outbound Proxy is signed by a custom Root CA, you may need to add it to the same Subscription configuration.

Add the following ConfigMap in the namespace the Operator is going to be installed into:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca 
  labels:
    # Magic label that will inject the cluster-wide trusted root CA bundle
    config.openshift.io/inject-trusted-cabundle: "true" 
# or you can manually add it
#data:
#  ca-bundle.crt: |
#    ------- BEGIN CERTIFICATE THINGS --------
#    ------- END CERTIFICATE THINGS --------
```

Then consume it in the Operator Subscription as shown:

```yaml
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: some-operator
spec:
  config: 
    selector:
      matchLabels:
        <labels_for_operator_pods>
    volumes: 
    - name: trusted-ca
      configMap:
        name: trusted-ca
        items:
          - key: ca-bundle.crt 
            path: tls-ca-bundle.pem 
    volumeMounts: 
    - name: trusted-ca
      mountPath: /etc/pki/ca-trust/extracted/pem
      readOnly: true
```

Again, sometimes that won't be inherited by the subsequent Operator resources deployed, and you may need to look for additional places to configure additional Root CAs.

---

## Operators in Disconnected Environments

In really disconnected environments, OLM isn't able to sync the built-in CatalogSources for the included OperatorHub items.

You'll mirror the Indexes - but the Indexes have the Bundles and their associated controllers that will need to be pulled to install the Operator.  And whatever images are used once the Operands are created and do their thing.

All this is metadata, within metadata, within metadata - some real Christopher Knight Shamalan sorta stuff.

The easiest way to manage Operators in disconnected environments is with `oc-mirror` v2.  You simply define some YAML for the Indexes:version, what Operators to mirror (or all?), and run the command.

> **BIG Note:**  Mirroring Operators will take a significant amount of disk space.  The default Operators from the single redhat-operator Index take about 1TB of space.

`oc-mirror` v2 also has a pretty good way to prune assets from image registries and clusters - to its credit, it's gotten much better.

### Create the ImageSetConfiguration

To use `oc-mirror` you need to whip up some YAML - you can use it to just mirror operators, and it's often best to just do OpenShift releases and Operator indexes separately.

Anywho, the following is a pretty good baseline for some very common OpenShift Operators.

```yaml
---
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  operators:
    - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.17
      # Don't download the full index unless you're sure you have a few hundred TB of space free
      # Setting full: true will download all the bundles of channels/versions for the listed operator packages
      # Setting full: true without a list of packages will download all bundles of all operators in the catalog
      #full: true
      packages:
        - name: advanced-cluster-management
        - name: ansible-automation-platform-operator
        - name: cincinnati-operator
        - name: devspaces
        - name: devworkspace-operator
        - name: kubernetes-nmstate-operator
        - name: kubevirt-hyperconverged
        - name: rhods-operator
        - name: local-storage-operator
        - name: lvms-operator
        - name: metallb-operator
        - name: mtv-operator
        - name: multicluster-engine
        - name: nfd
        - name: ocs-client-operator
        - name: odf-operator
        - name: openshift-gitops-operator
        - name: openshift-pipelines-operator-rh
        - name: quay-operator
        - name: redhat-oadp-operator
        - name: rhods-operator
        - name: rhacs-operator
```

See the documentation for how [additional filtering can be applied](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/disconnected_environments/mirroring-in-disconnected-environments#oc-mirror-operator-catalog-filtering_about-installing-oc-mirror-v2).

### Default OpenShift CatalogSources/Operator Indexes

- **Official Red Hat Operators:** registry.redhat.io/redhat/redhat-operator-index:v4.17
- **Marketplace Operators:** registry.redhat.io/redhat/redhat-marketplace-index:v4.17
- **Community Operators:** registry.redhat.io/redhat/community-operator-index:v4.17
- **Certified Operators:** registry.redhat.io/redhat/certified-operator-index:v4.17

Get the list of operators in the default configurations by doing one of the following:

```bash
# Get the list of Operator Bundles/PackageManifests in a connected cluster
oc get packagemanifests -A

# Get the list of Operator Bundles/PackageManifests via opm
```