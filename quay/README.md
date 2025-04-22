# Red Hat Quay

Red Hat provides a supported container image called Quay.  There is the hosted version online at quay.io, but that makes no difference for a disconnected environment - probably.

You can also deploy Red Hat Quay on-premise for your own private use.  You can deploy it on a RHEL system or on OpenShift via the Operator.

If you want to deploy it for use in OpenShift, well, you have a bit of a chicken and egg problem, unless the cluster you're deploying to is connected to the internet or some other private image registry to be installed from in the first place...

Anywho, you can find options for deploying it both ways below.  Some things like the "OpenShift Release Image Mirroring" Tekton Pipeline assumes the use of Quay deployed on the same cluster, but it's just as easy to get it to push to a different image registry.

## Deployment to RHEL

The deployment of Quay to a RHEL VM is considered a "Proof of Concept" deployment - there are some scaling and system considerations if you want it to serve large environments.

https://docs.redhat.com/en/documentation/red_hat_quay/3.14/html/proof_of_concept_-_deploying_red_hat_quay/index

## Deployment to OpenShift via the Quay Operator

1. Install the Red Hat Quay Operator
2. `oc apply -k quay/deploy`
3. ??????
4. PROFIT!!!!!1

## Post-install Quay Configuration

1. Access the Web UI
2. Create an account with the username of one of the users listed as superadmin in the Quay config.
3. Create an Organization, like `disconn-ocp`
4. Create a set of Repositories in that organization - I personally set it to Public to allow unauthenticated pull:
   1. `openshift/release` - this is where the actual images that make up an OpenShift release go
   2. `openshift/release-image` - this is where the index/metadata for OpenShift releases goes
   3. `openshift/operators` - this is where Operator images go
   4. `openshift/operator-indexes` - this is where Operator Index images go
5. In one of the Repositories in the Organization, navigate to Repository Settings.  Create a new Robot Account with Write permissions.  Add that Robot Account to the other repositories with Write permissions.
6. With the Robot Account created and applied to all the repositories, click on the Robot Account in one of the repos.  A modal window will pop up - download or view/copy the Kubernetes Secret, create it in the `disconn-tekton` Namespace/Project.
7. If you want to just mirror ALL 12k+ (as of this writing) image tags, you can configure the `openshift-releases` and `openshift-release-images` repositories to operator in Mirror mode - but this will mirror down all the images in the remote repositories on an interval.  It's a lot.  You should probably do it manually unless you have a reason to install OpenShift 4.4.
