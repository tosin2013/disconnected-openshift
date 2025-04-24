# Red Hat Advanced Cluster Management CVO Upstream Policy Example

When managing a fleet of clusters you can leverage things like GitOps - but maybe a policy driven approach would be better for some things?

You can find an example of an ACM Policy that will configure your targeted clusters to use a specified upstream OpenShift Update Service.

Simply install ACM, run `oc apply -k rhacm/`, and if your OSUS instance is running on that same ACM Hub then any cluster with the `cvo-upstream-hub-osus=true` label will have its ClusterVersion CR configured to use that OSUS instance.
