# Pipeline Setup Guide

## Overview

This guide details the setup and configuration of Tekton pipelines for automating container image management in a disconnected environment. The pipelines handle:
- Image mirroring from external registries
- Image building from source
- Image scanning and signing
- Automated updates and synchronization

## Prerequisites

### System Requirements
```bash
# Pipeline Requirements
✅ OpenShift Cluster Access
✅ Harbor Registry Access
✅ Storage for Pipeline Workspaces

# OpenShift Access Configuration
export KUBECONFIG=/home/lab-user/generated_assets/ocp4/auth/kubeconfig

# Verify cluster access
oc get co

# Access Information
Console URL: https://<your-domain>
Username: kubeadmin
Password: <provided during installation>
```

### Required Tools
```bash
# Verify OpenShift CLI
oc version

# Verify Tekton CLI
tkn version

# Verify cluster connection
oc whoami
oc get nodes
```

## Available Tasks

### 1. Buildah Task
Location: `tekton/tasks/buildah-disconnected.yml`
```yaml
# Task for building container images in disconnected environment
# Usage:
oc create -f tekton/tasks/buildah-disconnected.yml
tkn task list | grep buildah
```

### 2. Skopeo Copy Task
Location: `tekton/tasks/skopeo-copy-disconnected.yml`
```yaml
# Task for copying images between registries
# Usage:
oc create -f tekton/tasks/skopeo-copy-disconnected.yml
tkn task list | grep skopeo
```

### 3. OCP Release Tools Task
Location: `tekton/tasks/ocp-release-tools.yml`
```yaml
# Task for managing OpenShift release images
# Usage:
oc create -f tekton/tasks/ocp-release-tools.yml
tkn task list | grep ocp-release
```

## Setup Steps

### 1. Install Pipeline Operator
```bash
# Verify cluster access
oc whoami
oc get co

# Apply operator subscription
oc apply -f tekton/operator/subscription.yml

# Verify operator status
oc get csv -n openshift-operators | grep pipelines
```

### 2. Configure Storage
```bash
# Create pipeline storage class
oc apply -f tekton/storage/pipeline-storage.yml

# Create persistent volume claims
oc apply -f tekton/storage/pipeline-claims.yml
```

### 3. Setup Tasks
```bash
# Apply all tasks
oc apply -f tekton/tasks/

# Verify task installation
tkn task list
```

### 4. Configure Pipelines
```bash
# Apply pipeline definitions
oc apply -f tekton/pipelines/

# Verify pipeline installation
tkn pipeline list
```

## Pipeline Configuration

### 1. Image Mirror Pipeline
Location: `tekton/pipelines/mirror-images.yml`
```yaml
# Configure image mirroring
oc create -f tekton/pipelines/mirror-images.yml

# Run pipeline
tkn pipeline start mirror-images \
    --param source-registry=registry.redhat.io \
    --param target-registry=${HARBOR_HOSTNAME}
```

### 2. Image Build Pipeline
Location: `tekton/pipelines/build-images.yml`
```yaml
# Configure image building
oc create -f tekton/pipelines/build-images.yml

# Run pipeline
tkn pipeline start build-images \
    --param git-url=https://<your-domain> \
    --param image=${HARBOR_HOSTNAME}/app:latest
```

### 3. Image Scan Pipeline
Location: `tekton/pipelines/scan-images.yml`
```yaml
# Configure image scanning
oc create -f tekton/pipelines/scan-images.yml

# Run pipeline
tkn pipeline start scan-images \
    --param image=${HARBOR_HOSTNAME}/app:latest
```

## Verification

### 1. Test Pipeline Components
```bash
# Test buildah task
tkn task start buildah-disconnected \
    --param IMAGE=${HARBOR_HOSTNAME}/test:latest

# Test skopeo task
tkn task start skopeo-copy-disconnected \
    --param source=${HARBOR_HOSTNAME}/test:latest \
    --param destination=${HARBOR_HOSTNAME}/prod/test:latest
```

### 2. Verify Pipeline Runs
```bash
# Check pipeline status
tkn pipelinerun list

# View pipeline logs
tkn pipelinerun logs -f
```

### 3. Validate Results
```bash
# Check mirrored images
curl -k -u "admin:${HARBOR_PASSWORD}" \
    https://<your-domain>

# Verify image scans
curl -k -u "admin:${HARBOR_PASSWORD}" \
    https://<your-domain>
```

## Monitoring

### 1. Pipeline Metrics
```bash
# View pipeline metrics
oc get --raw /metrics | grep tekton

# Check resource usage
oc adm top pods -n tekton-pipelines
```

### 2. Task Status
```bash
# View task runs
tkn taskrun list

# Check workspace usage
oc get pvc -n tekton-pipelines
```

## Troubleshooting

### Common Issues

1. **Task Failures**
```bash
# View task logs
tkn taskrun logs <taskrun-name>

# Check pod events
oc get events -n tekton-pipelines
```

2. **Storage Issues**
```bash
# Check PVC status
oc get pvc -n tekton-pipelines

# View storage events
oc get events -n tekton-pipelines | grep volume
```

3. **Registry Access**
```bash
# Verify registry credentials
oc get secret registry-auth -n tekton-pipelines

# Test registry access
curl -k https://${HARBOR_HOSTNAME}/v2/
```

## Maintenance

### 1. Updates
```bash
# Update pipeline operator
oc patch subscription openshift-pipelines-operator-rh \
    --type=merge -p '{"spec":{"channel":"latest"}}'

# Update tasks
oc apply -f tekton/tasks/
```

### 2. Cleanup
```bash
# Clean old runs
tkn pipelinerun delete --keep 5

# Clean workspace data
oc delete pvc -l app=tekton-pipeline
```

### 3. Backup
```bash
# Backup pipeline configs
oc get pipeline,task -o yaml > pipeline-backup.yml

# Backup pipeline data
oc get pvc -l app=tekton-pipeline -o yaml > pipeline-pvc-backup.yml
```

## Security Considerations

1. **Access Control**
   - Use service accounts for pipeline runs
   - Configure RBAC for pipeline resources
   - Secure pipeline workspace storage

2. **Image Security**
   - Enable image scanning in pipelines
   - Configure image signing
   - Validate image sources

3. **Network Security**
   - Restrict egress traffic
   - Use internal registry endpoints
   - Configure TLS for registry access

## Reference

- [Tekton Documentation](https://<your-domain>
- [OpenShift Pipelines](https://<your-domain>
- [Pipeline Security](docs/security/pipeline-security.md)
- [Pipeline Best Practices](docs/operations/pipeline-best-practices.md) 