# Deploy Ansible Automation Platform on OpenShift

If you want to use the Ansible stuff in this repo you'll need a running instance of the Controller and EDA.  An easy way to deploy this is on OpenShift with the AAP Operator.

As of AAP 2.5, everything is deployed via the AnsibleAutomationPlatform CR.  For quick setup, you can deploy a Controller and EDA Platform instance with that following manifest:

```yaml
---
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatform
metadata:
  name: aap
  namespace: aap
spec:
  api:
    log_level: INFO
    replicas: 1
  database:
    postgres_data_volume_init: false
  ingress_type: Route
  no_log: true
  redis_mode: standalone
  route_tls_termination_mechanism: Edge
  service_type: ClusterIP
  lightspeed:
    disabled: true
  hub:
    disabled: true
```

Give it a little while and it should roll out all the database, Redis, Gateway, Controller, and EDA components.

---

## AAP Configuration

Assuming you want to use the example EDA > Tekton pipeline chain to automatically mirror images that are stuck in a ImagePullBackoff state, you can continue with the following instructions.

With the AAP instance deployed, you can create a few other objects that will provide some glue, like RBAC:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eda-auto-mirror-image
  namespace: aap
secrets:
  - name: eda-auto-mirror-image-token
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: eda-auto-mirror-image-token
  namespace: aap
  annotations:
    kubernetes.io/service-account.name: eda-auto-mirror-image
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: eda-pod-reader
rules:
  - verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
    apiGroups:
      - 'tekton.dev'
    resources:
      - pipelineruns
  - verbs:
      - get
      - list
      - watch
    apiGroups:
      - ''
    resources:
      - pods
# Only used if you're trying to do Podman-in-Pod config - not advised
#  - verbs:
#      - get
#      - list
#      - watch
#      - update
#      - use
#    apiGroups:
#      - security.openshift.io
#    resources:
#      - securitycontextconstraints
#    resourceNames:
#      - container-build
#      - anyuid
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: eda-auto-mirror-image
subjects:
  - kind: ServiceAccount
    name: default
    namespace: aap
  - kind: ServiceAccount
    name: eda-auto-mirror-image
    namespace: aap
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: eda-pod-reader

# Only used if you're trying to do Podman-in-Pod config - not advised
# ---
# kind: RoleBinding
# apiVersion: rbac.authorization.k8s.io/v1
# metadata:
#   name: eda-auto-mirror-image
#   namespace: aap
# subjects:
#   - kind: ServiceAccount
#     name: default
#     namespace: aap
#   - kind: ServiceAccount
#     name: eda-auto-mirror-image
#     namespace: aap
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: system:openshift:scc:container-build
```

These manifests will create a new ServiceAccount, and a Token for it.  There are some additional permissions that ServiceAccount is given in order to read Pods and create PipelineRuns.

1. Log into the AAP Gateway
2. Do the subscription thing
3. Create a new Organization/Teams/Groups/Users/Auth Providers if you want
4. Create a new **Execution Environment**, named `auto-mirror-image` with the EE image, eg `quay.io/kenmoini/ee-auto-mirror-image:latest`
5. Create a new **Decision Environment**, named `auto-mirror-iamge`, with the DE image, eg `quay.io/kenmoini/de-auto-mirror-image:latest`
6. Create a **Project** under **both** Automation Execution (Controller) and Automation Decision (EDA) - give it a name, point it to the fork of this repo, eg `https://gitea.apps.kemo.labs/kenmoini/disconnected-openshift.git`
  - **Note:** If you need to set Outbound HTTP Proxy configuration, do so with the environmental variable settings in Settings > Job.  Might be handy to also set `GIT_SSL_NO_VERIFY: 'true'`
7. Create a series of **Job Templates** under Automation Execution, one for the decision playbook and another for the execution playbook.  Make sure to enable "Prompt on Launch" for Extra Variables
8. Stitch those two Job Templates together in a **Workflow Template**.  Make sure "Prompt on launch" is checked for Extra Variables.  Add the extra variables `target_repo: disconn-harbor.d70.kemo.labs/man-mirror` and `substringParts: 1` and adjust accordingly.  The substringParts says how many slash-delimited parts of the source repository to remove from what is appended to the target_repo.
9. Create an **OAuth Application** under Access Management.  Password grand type, Public Client.
10. Under Users > (you) > Tokens, **make a Token** with that Application and a Write scope.
11. Take that User Token and create a new Red Hat Ansible Automation Platform type **EDA Credential** in Automation Decisions > Infrastructure > Credentials.
12. Create a **Rulebook Activation**, use the auto-mirror-image Rulebook and the intended DE.
13. Navigate in AAP to Automation Execution > Infrastructure > Instance Groups.  Either make a new Instance Group or configure the default one with the following **Pod configuration**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  namespace: aap
  labels:
    ansible_job: ''
spec:
  volumes:
    # The ServiceAccount token created earlier
    - name: token
      secret:
        secretName: eda-auto-mirror-image-token
  containers:
    - image: >-
        registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel8@sha256:b9f60d9ebbbb5fdc394186574b95dea5763b045ceff253815afeb435c626914d
      name: worker
      # This allows us to "automount" the serviceaccount token
      volumeMounts:
        - name: token
          mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          readOnly: true
      # Optional Proxy configuration
      env:
        - name: HTTP_PROXY
          value: http://proxy.kemo.labs:3129
        - name: HTTPS_PROXY
          value: http://proxy.kemo.labs:3129
        - name: http_proxy
          value: http://proxy.kemo.labs:3129
        - name: https_proxy
          value: http://proxy.kemo.labs:3129
        - name: NO_PROXY
          value: >-
            .kemo.labs,.kemo.network,.svc,.local,.cluster,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,172.30.0.1
        - name: no_proxy
          value: >-
            .kemo.labs,.kemo.network,.svc,.local,.cluster,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,172.30.0.1
      args:
        - ansible-runner
        - worker
        - '--private-data-dir=/runner'
      resources:
        requests:
          cpu: 250m
          memory: 100Mi
  serviceAccountName: default
  automountServiceAccountToken: false
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: ansible_job
                  operator: Exists
            topologyKey: kubernetes.io/hostname
```

With that AAP is now configured to process events, we just need to integrate OpenShift with it.

## OpenShift and EDA Integration

In order to send Alertmanager events to EDA, you need to configure at least the cluster Alertmanager configuration, and optionally create new PrometheusRules if the one you want is not available as part of the platform.

In this repo you can find a file under `rulebooks/auto-image-mirror/prometheusRule.yml` - this has some additional Prometheus Rules to define alerts for Pods that are stuck not able to pull images.  Apply that manifest to add those alerts to your cluster.

Next configure Alertmanager - in the OpenShift Administrative Web UI, navigate to Administration > Cluster Settings > Configuration > Alertmanager.  Hit the YAML tab and add the following receiver and route:

```yaml
receivers:
- name: "eda-auto-mirror-images"
  webhook_configs:
    - url: 'http://automatically-mirror-images.aap.svc:8000/endpoint'

route:
  routes:
  - receiver: "eda-auto-mirror-images"
    matchers:
      - "processor = eda"
    group_by:
      - alertname
```

By default, the EDA Alertmanager webhook listener is on `/endpoint` and the port is defined by the Rulebook - you can optionally override the endpoint.  The Service the receiver is pointing to is automatically created and maintained as part of the Rulebook Activation.

The Alertmanager Route provides routing of PrometheusRule definitions that have the `processor = eda` label to the receiver.

Make sure you have an ImageDigestMirrorSet and an ImageTagMirrorSet definition for wherever you're mirroring things, eg:

```yaml
---
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: manually-mirrored-registries
spec:
  imageDigestMirrors:
    - source: nvcr.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/man-mirror
---
apiVersion: config.openshift.io/v1
kind: ImageTagMirrorSet
metadata:
  name: manually-mirrored-registries
spec:
  imageTagMirrors:
    - source: nvcr.io
      mirrors:
        - disconn-harbor.d70.kemo.labs/man-mirror
```

> With all that you should start to see AAP process events for Pods that are in an ImagePullBackoff state and mirror them to a target repo.

---

## Extending the automation

The automation for automatically mirroring images could be adapted and extended in a variety of ways.

There is a mode of operation that supports using Podman to pull/tag/push an image which is useful when the node you're executing against is a Linux system.

For use in OpenShift, the automation will kick off the Tekton Pipeline that's provided as part of this repo in `tekton/` - this way each individual image can be mirrored in its own pipeline, letting for more atomic failure patterns.  Alternatively you can do Podman-in-Pod in OpenShift, but that requires a specially crafted Execution Environment and additional modifications to the platform to support that.

Currently it has a single `target_repo` endpoint variable - in more complex systems you may want to matrix this out to different registries or paths.

You could also add additional functionality to automate against your repository to dynamically create schema, and/or add a set of tasks to automatically process IDMS/ITMS entries.
