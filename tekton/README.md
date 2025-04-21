# Tekton/OpenShift Pipelines Assets

In this folder you can find a variety of Tekton manifests that can support different workflows needed to maintain a disconnected OpenShift environment.

- **Pipeline** - Build/Push OpenShift Binary Tools Container Image
- **Pipeline** - Build/Push OpenShift Release Tools Container Image
- **Pipeline** - Mirror OpenShift Release to Registry
- **Pipeline** - Mirror OpenShift Release to PVC (move with OADP to high-class net maybe)
- **Pipeline** - Mirror OpenShift Release from PVC
- **Task** - Disconnected Buildah
- **Task** - OpenShift Release Tools, a script wrapper really

There are other supporting assets such as PVCs, PipelineRuns, RBAC, and additional configuration to set for disconnected environments.

## Helpful Commands

- Clear failed Tekton tasks: `oc -n disconn-tekton delete pipelinerun $(oc -n disconn-tekton get pipelinerun -o jsonpath='{range .items[?(@.status.conditions[*].status=="False")]}{.metadata.name}{"\n"}{end}')`