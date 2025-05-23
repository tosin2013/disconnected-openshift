# Authentication Guide

## Overview

This guide covers authentication configuration and management for the disconnected OpenShift environment, including Harbor registry authentication, OpenShift authentication, and integration between components.

## Quick Reference

```bash
# Test Harbor authentication
podman login ${HARBOR_HOSTNAME} \
    --username admin \
    --password "${HARBOR_PASSWORD}"

# Create service account
oc create serviceaccount pipeline-sa -n openshift-pipelines

# Create registry secret
oc create secret docker-registry harbor-creds \
    --docker-server=${HARBOR_HOSTNAME} \
    --docker-username=admin \
    --docker-password="${HARBOR_PASSWORD}" \
    -n openshift-pipelines

# Link secret to service account
oc secrets link pipeline-sa harbor-creds \
    --for=pull,mount \
    -n openshift-pipelines
```

## Authentication Components

### 1. Harbor Registry Authentication

#### Local User Management
```bash
# Create Harbor project
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic <base64-credentials>
    "https://<your-domain> \
    -d '{"project_name": "test-project", "public": false}'

# Create Harbor user
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic <base64-credentials>
    "https://<your-domain> \
    -d '{
        "username": "pipeline-user",
        "email": "pipeline@example.com",
        "password": "StrongPassword123",
        "realname": "Pipeline User"
    }'
```

#### LDAP Integration
```yaml
# harbor-config.yaml
auth_mode: ldap_auth
ldap_url: "ldap://ldap.example.com"
ldap_base_dn: "dc=example,dc=com"
ldap_search_dn: "cn=admin,dc=example,dc=com"
ldap_search_password: "<your-secure-password>"
ldap_uid: "uid"
ldap_scope: 2
ldap_verify_cert: true
```

### 2. OpenShift Authentication

#### HTPasswd Authentication
```bash
# Create HTPasswd file
htpasswd -c -B -b users.htpasswd admin StrongPassword123

# Create secret
oc create secret generic htpass-secret \
    --from-file=htpasswd=users.htpasswd \
    -n openshift-config

# Configure OAuth
oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: htpasswd_provider
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF
```

#### LDAP Authentication
```yaml
# oauth-ldap.yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: ldap_provider
    mappingMethod: claim
    type: LDAP
    ldap:
      attributes:
        id: ["dn"]
        email: ["mail"]
        name: ["cn"]
        preferredUsername: ["uid"]
      bindDN: "cn=admin,dc=example,dc=com"
      bindPassword:
        name: ldap-secret
      ca:
        name: ca-config-map
      insecure: false
      url: "ldap://ldap.example.com/ou=users,dc=example,dc=com?uid"
```

### 3. Pipeline Authentication

#### Service Account Setup
```bash
# Create service account
oc create serviceaccount pipeline-sa -n openshift-pipelines

# Create role binding
oc create rolebinding pipeline-rolebinding \
    --clusterrole=edit \
    --serviceaccount=openshift-pipelines:pipeline-sa \
    -n openshift-pipelines

# Create registry credentials
oc create secret docker-registry harbor-creds \
    --docker-server=${HARBOR_HOSTNAME} \
    --docker-username=pipeline-user \
    --docker-password=StrongPassword123 \
    -n openshift-pipelines

# Link credentials to service account
oc secrets link pipeline-sa harbor-creds \
    --for=pull,mount \
    -n openshift-pipelines
```

#### Pipeline Task Authentication
```yaml
# task-with-auth.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: build-and-push
spec:
  workspaces:
    - name: source
  steps:
    - name: build-and-push
      image: quay.io/buildah/stable
      script: |
        buildah build --tls-verify=false -t ${HARBOR_HOSTNAME}/test-project/app:latest .
        buildah push --tls-verify=false ${HARBOR_HOSTNAME}/test-project/app:latest
      volumeMounts:
        - name: registry-creds
          mountPath: /var/run/secrets/registry
  volumes:
    - name: registry-creds
      secret:
        secretName: harbor-creds
```

## Authentication Validation

### 1. Harbor Authentication
```bash
# Test registry login
podman login ${HARBOR_HOSTNAME} \
    --username pipeline-user \
    --password StrongPassword123

# Test project access
curl -k -u "pipeline-user:StrongPassword123" \
    "https://<your-domain>

# Test image push
podman pull busybox
podman tag busybox ${HARBOR_HOSTNAME}/test-project/busybox:latest
podman push ${HARBOR_HOSTNAME}/test-project/busybox:latest
```

### 2. OpenShift Authentication
```bash
# Test user login
oc login -u pipeline-user -p StrongPassword123

# Test permissions
oc auth can-i create pods -n openshift-pipelines
oc auth can-i push --serviceaccount=pipeline-sa -n openshift-pipelines
```

### 3. Pipeline Authentication
```bash
# Test pipeline run with auth
tkn task start build-and-push \
    --workspace name=source,emptyDir="" \
    --serviceaccount=pipeline-sa \
    -n openshift-pipelines
```

## Troubleshooting

### Common Issues

1. **Harbor Login Failures**
   ```bash
   # Check Harbor service status
   oc get pods -n harbor
   
   # View Harbor core logs
   oc logs deployment/harbor-core -n harbor
   
   # Test Harbor API
   curl -k -v https://<your-domain>
   ```

2. **OpenShift Authentication Issues**
   ```bash
   # Check OAuth pods
   oc get pods -n openshift-authentication
   
   # View OAuth operator logs
   oc logs deployment/authentication-operator \
       -n openshift-authentication-operator
   
   # Check identity providers
   oc get oauth cluster -o yaml
   ```

3. **Pipeline Authentication Failures**
   ```bash
   # Verify secret exists
   oc get secret harbor-creds -n openshift-pipelines
   
   # Check secret is linked to service account
   oc describe serviceaccount pipeline-sa -n openshift-pipelines
   
   # Test registry access from pod
   oc run test --image=busybox --command -- sleep 3600
   oc exec test -- /bin/sh -c "ping ${HARBOR_HOSTNAME}"
   ```

## Best Practices

1. **Password Management**
   - Use strong passwords (minimum 12 characters)
   - Rotate credentials regularly
   - Use secrets management system
   - Avoid sharing credentials

2. **Access Control**
   - Follow principle of least privilege
   - Regular access reviews
   - Audit authentication events
   - Remove unused accounts

3. **Security Monitoring**
   - Monitor failed login attempts
   - Track credential usage
   - Alert on suspicious activity
   - Regular security audits

## Automation

### Authentication Scripts
```bash
# User management script
./scripts/manage-users.sh create pipeline-user

# Service account setup
./scripts/setup-pipeline-auth.sh

# Credential rotation
./scripts/rotate-credentials.sh
```

### Monitoring Scripts
```bash
# Check authentication status
./scripts/check-auth-status.sh

# Audit authentication
./scripts/audit-auth-events.sh

# Monitor failed logins
./scripts/monitor-failed-logins.sh
```

## Reference

- [OpenShift Authentication](https://<your-domain>
- [Harbor Authentication](https://<your-domain>
- [Tekton Authentication](https://<your-domain>

## Next Steps

1. Review [Certificate Management](certificate-guide.md)
2. Set up [Network Security](network-security.md)
3. Configure [Monitoring](../monitoring/auth-monitoring.md)
4. Implement automated credential rotation 