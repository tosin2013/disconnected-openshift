# GitOps Examples

If you're thinking of GitOps'ing things for your disconnected clusters then your mind is in the right place!

GitOps structures are super opinionated, and can vary drastically - there's no one good way to do it, just whatever works for you and your environment.  Different paths, different tools, different cluster and configurations matrixes - all sorts of ways to do it.

In here you can find some example manifests in a sample structure in order to give you a good foundation to start from.  It's organized as follows:

- `common/` - Things that are shared across clusters
  - `image-mirrors/` - IDMS/ITMS things.  Separated into two different folders for different mirrors (eg on-prem and cloud).  Basic Kustomize.
  - `outbound-proxy/` - Configuration to set the cluster Outbound Proxy.  Kustomize with Components.
  - `root-certificates/` - Simple Helm Chart file glob'ing
