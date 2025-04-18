# Disconnected OpenShift Environment Deployment Plan

## Overview
This document outlines the additional components and services required for a fully functional disconnected OpenShift environment, complementing the Harbor registry deployment.

## Phase 1: Binary and Asset Management

### 1.1 RHCOS Image Management
```bash
# Setup RHCOS mirror
cd rhcos/
# Download RHCOS images
./download-rhcos.sh ${OCP_VERSION}

# Configure HTTP server for serving images
oc apply -k extras/http-mirror/manifests/
```

### 1.2 OpenShift Client Tools
```bash
# Download and mirror OpenShift clients
cd binaries/
./download-ocp-binaries.sh

# Verify tools
oc version
openshift-install version
```

## Phase 2: HTTP Mirror Service

### 2.1 Deploy HTTP Mirror
```bash
# Deploy HTTP mirror service
oc apply -f extras/http-mirror/manifests/01_mirror-config.yml
oc apply -f extras/http-mirror/manifests/02_root-ca-certs.yml
oc apply -f extras/http-mirror/manifests/03_pvc.yml
oc apply -f extras/http-mirror/manifests/05_deployment.yml
oc apply -f extras/http-mirror/manifests/07_service.yml
oc apply -f extras/http-mirror/manifests/08_route.yml
```

### 2.2 Configure Mirror Content
1. Setup directory structure
2. Sync required assets
3. Verify mirror accessibility

## Phase 3: Infrastructure Services

### 3.1 DNS Configuration
1. Configure DNS zones:
   - OpenShift cluster domain
   - Application subdomain
   - Infrastructure services

2. Setup DNS records:
```bash
# Example DNS records
api.cluster.example.com    -> 192.168.50.x
*.apps.cluster.example.com -> 192.168.50.x
harbor.example.com        -> <ip-address>
```

### 3.2 DHCP Configuration
1. Configure DHCP ranges for each network:
   - Lab Network (<ip-address>/24)
   - Trans-Proxy Network (<ip-address>/24)
2. Set static IP reservations
3. Configure DHCP options (DNS, gateway)

### 3.3 Load Balancing
1. Deploy HAProxy/keepalived for API and ingress
2. Configure SSL termination
3. Setup health checks

## Phase 4: Certificate Management

### 4.1 PKI Setup
1. Configure root CA:
```bash
# Apply root CA configuration
oc apply -k gitops/common/root-certificates/
```

2. Generate service certificates:
   - API endpoint
   - Default ingress
   - Monitoring
   - Registry

### 4.2 Certificate Distribution
1. Configure trust bundle:
```bash
# Update cluster trust bundle
oc create configmap custom-ca \
    --from-file=ca-bundle.crt=/path/to/ca-bundle \
    -n openshift-config
```

2. Configure certificate rotation

## Phase 5: Automation Setup

### 5.1 Tekton Pipeline Deployment
```bash
# Deploy base Tekton components
oc apply -k tekton/config/

# Deploy specific pipelines
oc apply -k tekton/pipelines/
```

### 5.2 Ansible Automation
1. Configure Ansible automation:
```bash
# Deploy automation components
cd playbooks/auto-mirror-image/
ansible-playbook main.yml
```

2. Setup decision environments:
```bash
# Build decision environments
cd decision-environments/auto-mirror-image/
podman build -t auto-mirror-de .
```

## Phase 6: Monitoring and Logging

### 6.1 Prometheus Configuration
```bash
# Deploy monitoring rules
oc apply -f rulebooks/auto-image-mirror/prometheusRule.yml
```

### 6.2 Alert Configuration
1. Setup alert rules
2. Configure alert routing
3. Setup notification channels

### 6.3 Logging Setup
1. Deploy logging stack
2. Configure log retention
3. Setup log forwarding

## Phase 7: Testing and Validation

### 7.1 Infrastructure Testing
1. Verify DNS resolution
2. Test load balancer failover
3. Validate certificate chain

### 7.2 Automation Testing
1. Test Tekton pipelines
2. Validate Ansible playbooks
3. Verify decision environments

### 7.3 Monitoring Validation
1. Check Prometheus metrics
2. Test alert triggering
3. Verify log collection

## References
- [HTTP Mirror Documentation](extras/http-mirror/README.md)
- [Binary Management](binaries/README.md)
- [RHCOS Documentation](rhcos/README.md)
- [Tekton Pipeline Documentation](tekton/README.md)
- [Automation Playbooks](playbooks/auto-mirror-image/README.md) 