# Harbor Deployment Guide

> ⚠️ **Documentation Update Notice**
> 
> This documentation has been moved and split into two comprehensive guides:
> 
> 1. **Primary Deployment Guide (Recommended)**:  
>    [`../core/registry/deploy-harbor-docker-compose.md`](../core/registry/deploy-harbor-docker-compose.md)
>    - Container-based deployment using Tekton
>    - OpenShift integration
>    - Modern automation practices
>
> 2. **Legacy VM Deployment Guide**:  
>    [`../reference/alternative-implementations/vm-harbor-install.md`](../reference/alternative-implementations/vm-harbor-install.md)
>    - Traditional VM-based deployment using `deploy-harbor-vm.sh`
>    - Manual configuration steps
>    - Legacy setup
>
> Please update your bookmarks accordingly.

## Quick Reference

For your convenience, here are the key locations for Harbor-related documentation:

1. **Core Documentation**
   - [Harbor Deployment Guide](../core/registry/deploy-harbor-docker-compose.md)
   - [Pull-through Cache Configuration](../core/registry/pullthrough-proxy-cache-harbor.md)
   - [Registry Monitoring](../reference/monitoring/harbor-monitoring.md)

2. **Integration Guides**
   - [OpenShift Integration](../core/openshift/agent-installation.md)
   - [Development Workflow](../environment/development-workflow.md)
   - [Security Best Practices](../security/README.md)

3. **Reference Materials**
   - [Architecture Decision Records](../adr/0009-openshift-agent-installation.md)
   - [Alternative Implementations](../reference/alternative-implementations/vm-harbor-install.md)

## Overview

Harbor serves as the central container registry for:
- OpenShift container images
- Custom application images
- Helm charts
- Container signing and scanning

## Prerequisites

### System Requirements
```bash
# Harbor Host Requirements
✅ CPU: 4+ cores
✅ RAM: 8GB+ (16GB recommended)
✅ Storage: 500GB+ available
✅ Network: Access to both networks
   - Management Network for initial setup
   - Disconnected Network for air-gapped operation

# Required Tools
kcli --version
ansible --version
openssl version
```

## Environment Variables

For reference, these are the key environment variables used across both deployment methods:

```bash
# Required Environment Variables
HARBOR_HOSTNAME="your-harbor-hostname"      # Harbor registry FQDN
HARBOR_ADMIN_PASSWORD="secure-password"     # Admin password for Harbor
REGISTRY_CERTIFICATE_PATH="/path/to/certs"  # Path to registry certificates

# Optional Environment Variables
HARBOR_DATA_VOLUME="/var/lib/harbor"        # Data directory for Harbor
HARBOR_VERSION="v2.10.0"                    # Harbor version to deploy
HARBOR_HTTP_PROXY=""                        # HTTP proxy if required
HARBOR_HTTPS_PROXY=""                       # HTTPS proxy if required
HARBOR_NO_PROXY=""                          # No proxy list
```

## VM Deployment

For VM-based deployment, use the provided script:

```bash
# Deploy Harbor VM
./scripts/deploy-harbor-vm.sh
```

The script handles:
- VM provisioning with required specifications
- Base Harbor installation
- Initial configuration setup

For additional configuration and management, refer to the [VM-Based Harbor Installation Guide](../reference/alternative-implementations/vm-harbor-install.md).

## Container Deployment

### Option 1: Tekton-based Deployment (Recommended)

For container-based deployment using Tekton, refer to the [Primary Deployment Guide](../core/registry/deploy-harbor-docker-compose.md).

### Option 2: Direct Container Deployment

This method uses docker/docker directly to deploy Harbor.

1. **Download the Harbor Installer**
```bash
# Download the offline installer
wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz

# Extract the package
tar xzvf harbor-offline-installer-v2.10.0.tgz
cd harbor
```

2. **Configure Harbor**
```bash
# Copy the template configuration file
cp harbor.yml.tmpl harbor.yml

# Edit the configuration
# Required changes:
# - hostname: Set to your Harbor FQDN
# - https: Configure certificate paths
# - harbor_admin_password: Set secure admin password
vi harbor.yml
```

Example `harbor.yml` configuration:
```yaml
hostname: ${HARBOR_HOSTNAME}
https:
  certificate: ${REGISTRY_CERTIFICATE_PATH}/harbor.crt
  private_key: ${REGISTRY_CERTIFICATE_PATH}/harbor.key

# Initial password for Harbor admin
harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

# The default data volume
data_volume: ${HARBOR_DATA_VOLUME}

# Harbor Storage settings
storage_service:
  ca_bundle: /etc/ssl/certs/ca-certificates.crt
  paths:
    - /data
    - /storage

# Database settings
database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900

# Set the logging level
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
```

3. **Prepare Installation**
```bash
# Generate certificates if needed
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout ${REGISTRY_CERTIFICATE_PATH}/harbor.key \
  -out ${REGISTRY_CERTIFICATE_PATH}/harbor.crt \
  -subj "/CN=${HARBOR_HOSTNAME}/O=Harbor/C=US"

# Update trust store
sudo cp ${REGISTRY_CERTIFICATE_PATH}/harbor.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

4. **Run the Installation Script**
```bash

# Or install with Docker
./install.sh --with-docker
```

5. **Verify Installation**
```bash
# Check container status
docker ps -a | grep harbor

# Verify Harbor is running
curl -k https://${HARBOR_HOSTNAME}/api/v2.0/health

# Login to Harbor
docker login ${HARBOR_HOSTNAME}
```

6. **Post-Installation Steps**

Configure garbage collection:
```bash
# Edit the garbage collection settings in Harbor UI:
# System Management -> Garbage Collection -> Schedule
# Recommended: Weekly cleanup during low-usage hours
```

Configure system resource limits:
```bash
# Edit docker-compose.yml or docker-compose.yml
services:
  harbor-core:
    mem_limit: 8g
    memswap_limit: 16g
  registry:
    mem_limit: 4g
    memswap_limit: 8g
```

## OpenShift Integration

### 1. Configure Harbor for OpenShift

Add the following to your OpenShift agent installer configuration (`cluster.yml`):

```yaml
disconnected_registries:
  # OpenShift release images
  - target: ${HARBOR_HOSTNAME}/openshift/release
    source: quay.io/openshift-release-dev/ocp-release
  - target: ${HARBOR_HOSTNAME}/openshift/release-art
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
  # General registries
  - target: ${HARBOR_HOSTNAME}/quay-io
    source: quay.io
  - target: ${HARBOR_HOSTNAME}/redhat-io
    source: registry.redhat.io
  - target: ${HARBOR_HOSTNAME}/redhat-connect
    source: registry.connect.redhat.com

# Harbor CA certificate
additional_trust_bundle_policy: Always
additional_trust_bundle: |
  -----BEGIN CERTIFICATE-----
  # Add your Harbor CA certificate here
  -----END CERTIFICATE-----
```

### 2. Verify OpenShift Integration
```bash
# Test pulling OpenShift images
docker pull ${HARBOR_HOSTNAME}/openshift/release:4.18.0-x86_64

# Verify replication status
curl -k -u "admin:${HARBOR_ADMIN_PASSWORD}" \
    https://${HARBOR_HOSTNAME}/api/v2.0/replication/executions
```

## Verification

### 1. Test Registry Access
```bash
# Login to registry
docker login ${HARBOR_HOSTNAME}

# Pull and push test image
docker pull ubi8/ubi:latest
docker tag ubi8/ubi:latest ${HARBOR_HOSTNAME}/library/ubi:latest
docker push ${HARBOR_HOSTNAME}/library/ubi:latest
```

### 2. Verify Harbor API
```bash
# Check Harbor health
curl -k https://${HARBOR_HOSTNAME}/api/v2.0/health

# List projects (requires authentication)
curl -k -u "admin:${HARBOR_ADMIN_PASSWORD}" \
    https://${HARBOR_HOSTNAME}/api/v2.0/projects

# Check system info
curl -k -u "admin:${HARBOR_ADMIN_PASSWORD}" \
    https://${HARBOR_HOSTNAME}/api/v2.0/systeminfo
```

## Troubleshooting

### Common Issues

1. **Certificate Problems**
```bash
# Generate new self-signed certificate
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/harbor.key \
  -out /etc/ssl/certs/harbor.crt \
  -subj "/CN=${HARBOR_HOSTNAME}/O=Harbor/C=US"

# Update trust store
sudo cp /etc/ssl/certs/harbor.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

2. **Authentication Issues**
```bash
# Reset admin password using Harbor API
curl -k -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"old_password":"old_password","new_password":"new_password"}' \
  https://${HARBOR_HOSTNAME}/api/v2.0/users/1/password

# Clear existing credentials
rm -f ~/.docker/config.json
```

3. **Storage Issues**
```bash
# Check storage usage
df -h ${HARBOR_DATA_VOLUME}

# View Harbor container logs
docker logs harbor-core
docker logs harbor-registry

# Check Harbor database status
docker logs harbor-db
```

## Need Help?

If you encounter any issues or need assistance:

1. Check the [Troubleshooting Guide](../core/registry/deploy-harbor-docker-compose.md#troubleshooting)
2. Review the [Security Best Practices](../security/README.md)
3. Consult the [Harbor Official Documentation](https://goharbor.io/docs/2.10.0/)
4. Contact the infrastructure team for support 