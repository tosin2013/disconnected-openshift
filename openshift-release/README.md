# Mirroring OpenShift Releases

Mirroring OpenShift release images is step 2 after gathering the needed binaries - binaries namely being `oc` and `oc-mirror`.

You can mirror with either `oc` or `oc-mirror` - they both work.  The `oc` interface may be easier from a pure command line view, while if you're not afraid of making some YAML, `oc-mirror` (v2) can make things easier.

An important note: You will need two repository paths for OpenShift Releases:

- `openshift` - The images that make up an actual release (eg the 192 images for 4.17.12).  This is from the upstream `quay.io/openshift-release-dev/ocp-v4.0-art-dev` repo.
- `openshift-release` - The images that define an actual release (eg `:4.17.12-x86_64`).  This is from the upstream `quay.io/openshift-release-dev/ocp-release` repo.

These CANNOT be in the same repo.  OpenShift expects them in different places, and things like OpenShift Update Service will fail.

## Get a Container Image Registry

In order to avoid a chicken-egg problem, it's often best to have a container image registry located outside of OpenShift.

You can easily deploy [JFrog Artifactory](../docs/deploy-jfrog-podman.md), [Harbor](../docs/deploy-harbor-podman-compose.md), [Nexus](https://vcojot.blogspot.com/2024/12/sonatype-nexus-and-openshift-are.html), or even [Quay](https://docs.redhat.com/en/documentation/red_hat_quay/3.14/html/proof_of_concept_-_deploying_red_hat_quay/index) in a VM somewhere.

## Configure the Container Image Registry - Proxy/Pull-through Cache

If I haven't made myself clear yet, the best option if your container image registry is connected to the Internet and accessible by networks/systems that otherwise do not have outbound Internet connectivity, is to have it proxy container images from upstream resources to downstream consumers.  This way you can avoid having to manually mirror images.

You can find instructions linked on configuring [JFrog Artifactory](../docs/pullthrough-proxy-cache-jfrog.md), [Harbor](../docs/pullthrough-proxy-cache-harbor.md), and [Nexus](https://vcojot.blogspot.com/2024/12/sonatype-nexus-and-openshift-are.html) as proxy/pull-through caches.

## Configure the Container Image Registry - Manually Mirroring

In case you need to manually mirror images, you need to make a few repositories - maybe, depending on how you mirror things.

If you're using `oc` then you can make repositories generally along any path, but it's best to stick to a max of two sub-paths - eg:

- `openshift` images: `disconnected-harbor.example.com/manual-mirrored-things/openshift`
- `openshift-release` images: `disconnected-harbor.example.com/manual-mirrored-things/openshift-release`

If you're using the `oc-mirror` v2 command, then it will automatically create the `openshift/release` and `openshift/release-images` repository sub-paths along whatever path you provide as the target.  So in this instance your target repository would be `disconnected-harbor.example.com/manual-mirrored-things`.

These are pathing considerations - in either case, you'll log into your container image registry, create a new Repository/Project/whatever called `manual-mirrored-things`, create an account, give it pull/push permissions, and the mirroring process takes care of creating the sub-paths.

## OpenShift Release Mirroring Resources

In this repository you'll find some supporting resources to make mirroring OpenShift Releases easier:

- **OpenShift Binary Tools** - The container that has any binaries we need added to it like `oc`, `oc-mirror`, etc.
  - [ADO Pipeline](../binaries/azure-pipelines.yml)
  - [Container](../binaries/Containerfile)
  - [Container, FIPS](../binaries/Containerfile.fips)
  - [GitHub Action](../.github/workflows/binaries-build-container.yml)
  - [Helper Script](../binaries/download-ocp-binaries.sh)
- **OpenShift Release Tools** - Container built on top of the OpenShift Binary Tools container, has extra binaries/scripts that help with mirroring OpenShift Release Images, Operators, etc.
  - [Container](../openshift-release/Containerfile)
  - [GitHub Action](../.github/workflows/openshift-release-tools-build-container.yml)
  - [oc Helper Script](../openshift-release/mirror-release.sh) - Mirroring via `oc`
  - [oc-mirror Helper Script](../openshift-release/oc-mirror.sh) - Mirroring via `oc-mirror` v2
  - [OCP Release Signature Helper Script](../openshift-release/make-ocp-release-signature.sh) - After mirroring a release, the Red Hat public key that signs it needs to be added as a ConfigMap before it can be used by a cluster for an update.  This script generates those ConfigMaps.
- **Tekton Assets** - Set of things that help make Tekton work in disconnected networks.
  - [Task, buildah-disconnected](../tekton/tasks/buildah-disconnected.yml) - Additional configuration for disconnected networks when using buildah to build images
  - [Task, skopeo-copy-disconnected](../tekton/tasks/skopeo-copy-disconnected.yml) - Additional configuration for disconnected networks when using skopeo
  - [Task, ocp-release-tools](../tekton/tasks/ocp-release-tools.yml) - Handles execution of the OpenShift Release Tools image in Tekton for mirroring releases
  - [Pipeline, Build Container - OpenShift Binary Tools](../tekton/pipelines/build-container-ocp-binary-tools.yml) - Pipeline to build the OpenShift Binaries Tool container and push to the internal registry
  - [Pipeline, Build Container - OpenShift Release Tools](../tekton/pipelines/build-container-ocp-release-tools.yml) - Pipeline to build the OpenShift Release Tool container and push to the internal registry
  - [Pipeline, Build Container - OSUS Graph Data](../tekton/pipelines/build-container-osus-graph-data.yml) - Pipeline to build the OpenShift Update Service (OSUS) Graph Data container and push to the internal registry
  - [Pipeline, OpenShift Release Mirror, To Directory](../tekton/pipelines/ocp-release-mirror-to-dir.yml) - Pipeline to mirror from an upstream registry to a directory (in a PVC)
  - [Pipeline, OpenShift Release Mirror, From Directory](../tekton/pipelines/ocp-release-mirror-from-dir.yml) - Pipeline to mirror from a directory (in a PVC) to a local private registry
  - [Pipeline, OpenShift Release Mirror, To Registry](../tekton/pipelines/ocp-release-mirror-to-registry.yml) - Pipeline to mirror directly from an upstream registry to a local private registry
  - [Pipeline, Skopeo Copy Disconnected](../tekton/pipelines/skopeo-copy-disconnected-single.yml) - Pipeline to copy container images around with extra disconnected config
  - PipelineRuns for the various Pipelines are included as well

## Post OpenShift Release Mirroring

After you mirror a release it's not able to be used by OpenShift for updates unless you force it to (not advised), or unless you create a special ConfigMap in the `openshift-config-managed` Namespace with a special `release.openshift.io/verification-signatures=` label, and the public key for the release stuffed into some binaryData, with the shasum specially formatted as the key.

This can easily be done with the little helper script [make-ocp-release-signature.sh](./make-ocp-release-signature.sh)

It takes in one parameter, and other functions are handled by environmental variables.

```yaml
# DRY_RUN is suggested, others are suggested overrides when interacting with a private registry
# - but the signature is still stored on RH HTTP servers, so still need to be connected so why not go through Quay.io
DRY_RUN="false" \
 LOCAL_REGISTRY="quay.io" \
 LOCAL_REGISTRY_RELEASE_PATH="openshift-release-dev/ocp-release" \
 ARCHITECTURE="x86_64" \
 ./make-ocp-release-signature.sh 4.17.12
```

This ConfigMap needs to be distributed to the various clusters consuming your disconnected OSUS instance.  This could be done via ACM/GitOps without much adaptation.