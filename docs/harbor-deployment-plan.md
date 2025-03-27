# Harbor Deployment and Integration Plan

## Overview
This document outlines the step-by-step process for deploying Harbor registry in a dual-network configuration and integrating it with OpenShift.

## Phase 1: Infrastructure Setup

### 1.1 Deploy Harbor using kcli
```bash
# Deploy Harbor VM
sudo kcli create vm -p harbor plans/harbor.yml

# Verify VM status
sudo kcli list vm
```

### 1.2 Network Configuration
- Primary Network (Connected):
  * Network: <ip-address>/24
  * Harbor IP: <ip-address>
  * Gateway: <ip-address>
  * Shared with OpenShift cluster

- Secondary Network (Trans-Proxy):
  * Network: <ip-address>/24
  * Harbor IP: <ip-address>
  * Gateway: <ip-address>
  * For disconnected operations

### 1.3 Verify Connectivity
```bash
# Test connected network
ping <ip-address>
curl -k https://<your-domain>

# Test trans-proxy network
ping <ip-address>
curl -k https://<your-domain>
```

## Phase 2: Harbor Configuration

### 2.1 Pull-Through Cache Setup
```bash
# Convert pull secret to Harbor format
./scripts/pull-secret-to-harbor-auth.sh /path/to/pull-secret.json

# Create registry endpoints using converted credentials
# Follow docs/pullthrough-proxy-cache-harbor.md
```

### 2.2 Project Configuration
1. Create projects for each registry:
   - quay-ptc
   - registry-redhat-io-ptc
   - registry-connect-redhat-com-ptc

2. Configure proxy cache settings for each project
3. Setup robot accounts for authentication

### 2.3 SSL Certificate Configuration
1. Generate or obtain SSL certificates
2. Configure Harbor to use certificates
3. Add certificates to OpenShift's trust bundle

## Phase 3: OpenShift Integration

### 3.1 GitOps Configuration
1. Apply image mirror configurations:
```bash
# Apply image mirror configurations
oc apply -k gitops/common/image-mirrors/disconn-harbor.d70.kemo.labs/
```

2. Update root certificates:
```bash
# Apply root certificate configurations
oc apply -k gitops/common/root-certificates/
```

### 3.2 Image Mirror Configuration
1. Configure ImageDigestMirrorSet
2. Configure ImageTagMirrorSet
3. Verify mirror configuration:
```bash
oc get ImageDigestMirrorSet
oc get ImageTagMirrorSet
```

## Phase 4: Pipeline Setup

### 4.1 Deploy Tekton Components
```bash
# Apply Tekton configurations
oc apply -k tekton/config/

# Deploy pipelines
oc apply -k tekton/pipelines/

# Deploy tasks
oc apply -k tekton/tasks/
```

### 4.2 Configure Pipeline Authentication
1. Create secrets for registry authentication
2. Configure service accounts
3. Apply RBAC configurations

## Phase 5: Testing and Validation

### 5.1 Image Mirroring Test
```bash
# Test single image mirroring
oc create -f tekton/pipeline-runs/skopeo-copy-disconnected/05_plr-skopeo-copy-disconnected-single.yml
```

### 5.2 OpenShift Integration Test
1. Verify image pulls from Harbor
2. Test image stream imports
3. Validate build configurations

### 5.3 Disconnected Operation Test
1. Simulate disconnected environment
2. Verify image pulls continue working
3. Test image mirroring in disconnected mode

### 5.4 Pipeline Validation
1. Run test pipeline
2. Verify image synchronization
3. Validate error handling

## References
- [Harbor Documentation](docs/deploy-harbor-podman-compose.md)
- [Pull-Through Cache Setup](docs/pullthrough-proxy-cache-harbor.md)
- [GitOps Configuration](gitops/README.md)
- [Tekton Pipeline Documentation](tekton/README.md) 