# Tekton/OpenShift Pipelines Assets

In this folder you can find a variety of Tekton manifests that can support different workflows needed to maintain a disconnected OpenShift environment.

- `./binaries/` - Pipeline, PipelineRun, and supporting objects to build a container that houses needed OpenShift binaries (oc, openshift-install, etc), and pushes to a registry.
- `./openshift-release/` - Pipeline/PipelineRun/etc for building a container with a script used to mirror OpenShift releases.  Another Pipeline/PipelineRun/etc for actually mirroring OpenShift release container images.