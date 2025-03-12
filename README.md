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
4. Deploy OpenShift - Disconnected Installation Examples
5. Configure disconnected cluster settings (Root CAs, Proxy, Image mirrors, etc)
6. Mirroring Operators
7. Creating an Update Graph Container
8. Using custom CatalogSources
9. Deploying the OpenShift Update Service Operator
10. Automate the steps

## Additional Resources

- [Extras](./extras/) - Small helpful quick references eg deploying an NGINX container on Podman, and a HTTP server that will automatically mirror assets.
- [Tekton Resources](./tekton/) - Build containers in disconnect environments, run mirroring pipelines
- [Dev/Test Quay](./quay/) - A quick way to deploy Quay via the Operator on OpenShift for some quick testing, not configured for production.