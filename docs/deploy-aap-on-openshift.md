# Deploy Ansible Automation Platform on OpenShift

If you want to use the Ansible stuff in this repo you'll need a running instance of the Controller and EDA.  An easy way to deploy this is on OpenShift with the AAP Operator.

As of AAP 2.5, everything is deployed via the AnsibleAutomationPlatform CR.  For quick setup, you can deploy a Controller and EDA Platform instance with that following manifest:

```yaml
---
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatform
metadata:
  name: aap
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