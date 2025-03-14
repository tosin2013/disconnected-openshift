# Disconnected OpenShift - A Compendium

> This repo is a work in progress as I gather various different sources into this one place and make my garbage scripts less trashy.

To deploy OpenShift in disconnected, semi-connected, and barely-connected environments, you have to figure for a few things

- Binaries
- OpenShift Release Container Images
- RHCOS Media
- Operators
- OpenShift Update Service and Graph Data
- etc

This repository is meant to make all that easier.  It features:

- Things for Outbound HTTP Proxies!
- Custom Root CA helpers for Outbound HTTP Proxies that do SSL MitM!
- Private image registry pointers!
- Multi-arch and FIPS examples where available!
- Disconnected Installation examples!
- Azure DevOps Pipelines, GitHub Actions, Ansible Automation/EEs, and/or Tekton Pipelines when/where available!
- RHACM Policy examples for distributing disconnected configuration!
- Stuff for ACM, DevSpaces, OpenShift AI, Quay, Virtualization, and more!

## Prerequisites

- **Pull Secrets** - Container Registry Pull Secrets for Red Hat Registries as well as your own.  You can find a handy script in [./scripts/join-auths.sh](./scripts/join-auths.sh) to combine two JSON pull secret files into one.
- **A Container Image Registry** - This can be an existing Harbor, JFrog Artifactory, Sonatype Nexus, Red Hat Quay, etc deployment.  You need some place to mirror container images to.  Examples for deploying different container image registries are provided in this repo.
- **An HTTP server** - While not always needed, often comes in handy.  Examples for deploying some HTTP servers are provided in this repo.
- **A Linux Server** - Not always needed by often is.  Any ol' Linux server, physical, virtual, a laptop will even do, ideally RHEL 9 but could be other distros.

## Walkthrough

1. [Download/Mirror OpenShift Binaries](./binaries/)
2. [Mirror OpenShift Release Container Images](./openshift-release/)
3. [Obtain RHCOS assets](./rhcos/)
4. [Deploy OpenShift - Disconnected Installation Examples](./installation-examples/)
5. [Post-Install Configuration (Root CAs, Proxy, Image mirrors, etc)](./post-install-config/)
6. Mirroring Operators
7. Creating an Update Graph Container
8. Using custom CatalogSources
9. Deploying the OpenShift Update Service Operator
10. Automate the steps

## Additional Resources

- [Extras](./extras/) - Small helpful quick references eg deploying an NGINX container on Podman, and a HTTP server that will automatically mirror assets.
- [Tekton Resources](./tekton/) - Build containers in disconnect environments, run mirroring pipelines
- [Dev/Test Quay on OpenShift](./quay/) - A quick way to deploy Quay via the Operator on OpenShift for some quick testing, not configured for production.
- [Dev/Test Harbor on Podman](./docs/deploy-harbor-podman-compose.md) - A easy/quick way to deploy Harbor with little more than a RHEL VM and Podman Compose.
- [Configure Pull-through Proxy Cache, Harbor](./docs/pullthrough-proxy-cache-harbor.md) - Guide to setup Harbor to act as a Pull-through/Proxy Cache.
- [Configure Pull-through Proxy Cache, JFrog](./docs/pullthrough-proxy-cache-jfrog.md) - Guide to setup JFrog to act as a Pull-through/Proxy Cache.

---

## How to not do any of this

Mirroring OpenShift assets for a disconnected deployment can be daunting.  It can certainly be automated, and you'll find examples of that here - *but what if there were a better way?*

It's common for environments to have some sort of artifact/container repository - something like JFrog Artifactory, Sonatype Nexus, Harbor, etc.  Often used for proxying in developer assets such as dependencies, images, modules, etc.

If you have this already and can use it to do the same sort of proxying for container images from public sources and provide them internally then all this gets much simpler.

All you need to do in this instance is:

- Create the Proxy Repos in whatever Registry you use, point them to Quay and the Red Hat Registry at a minimum, eg `quay.io = quay-ptc.registry.example.com`
- Combine your private Pull Secret with the Red Hat ones
- Add that pull secret, any Root CAs, the mirror configuration for the imageMirrorSources.

***And that's it!***

Install from there, no other manual methods for mirroring images, creating Operator Indexes, etc.  Any time a workload on OpenShift calls out to `quay.io` it will be pointed to `quay-ptc.registry.example.com` instead under the covers of everything.  There are some guides on setting things up:

- [Configure Pull-through Proxy Cache, Harbor](./docs/pullthrough-proxy-cache-harbor.md) - Guide to setup Harbor to act as a Pull-through/Proxy Cache.
- [Configure Pull-through Proxy Cache, JFrog](./docs/pullthrough-proxy-cache-jfrog.md) - Guide to setup JFrog to act as a Pull-through/Proxy Cache.

***There is a caveat*** - that if your cluster can't talk to the Internet, while you can access container images transparently with this Pull-Through Cache/Proxy, the Update Graph data is not in a container.  This is on `api.openshift.com` and if you can't access that you'll still need to curate the Graph and Update Service - but otherwise there are no containers to really mirror this way.  If you can use a container registry acting as a remote pull-through cache/proxy then everything gets so much easier.

Also, in earnest, there are still a few switches to flip with a Pull-through/Proxy Cache, but it's still easier than manual methods of mirroring things.  Namely you still need to:

- Add Root CAs
- Have Pull Secrets to pull from your private registry mirror(s)
- Create ImageDigestMirrorSets and ImageTagMirrorSets
- Set the Samples Operator Config to `Managed` from `Removed`
- Configure the Image Config CR
- Adjust for things like OpenShift Virt that doesn't use the global mirror config
- Run an OpenShift Update Service instance

But that's a much shorter list than all the other mirroring stuff.  If you can use a local proxy cache and an Outbound HTTP Proxy, then you can even skip the OSUS instance - really with an Outbound HTTP Proxy you can skip most of this stuff though.
