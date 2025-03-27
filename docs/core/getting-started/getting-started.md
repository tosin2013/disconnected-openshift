# Getting Started Guide

## Introduction

This guide will walk you through setting up a disconnected OpenShift environment from scratch. By the end, you'll have:
- A fully functional OpenShift 4.18 cluster
- A secure Harbor registry for storing images
- Ansible Automation Platform (AAP) for automation
- Everything configured for disconnected operation

## Prerequisites Checklist

### 1. Hardware Requirements
```bash
# Verify your system meets these requirements:
❏ CPU: 8+ cores
  $ lscpu | grep "CPU(s):"
  
❏ RAM: 32GB+
  $ free -h
  
❏ Storage: 1TB+ available
  $ df -h
```

### 2. Network Requirements
```bash
# Verify network access:
❏ Lab Network (<ip-address>/24)
  $ ping <ip-address>
  
❏ Trans-Proxy Network (<ip-address>/24)
  $ ping <ip-address>
```

### 3. Required Tools
```bash
# Install and verify each tool:

❏ podman
  $ sudo dnf install podman
  $ podman --version
  
❏ buildah
  $ sudo dnf install buildah
  $ buildah --version
  
❏ skopeo
  $ sudo dnf install skopeo
  $ skopeo --version
  
❏ ansible
  $ sudo dnf install ansible
  $ ansible --version
  
❏ OpenShift CLI (oc)
  $ curl -LO https://<your-domain>
  $ tar xvf openshift-client-linux.tar.gz
  $ sudo mv oc /usr/local/bin/
  $ oc version
```

## Initial Setup

### 1. Clone the Repository
```bash
git clone https://<your-domain>
cd disconnected-openshift
```

### 2. Environment Validation
```bash
# Run the validation script
./scripts/validate-environment.sh

# This will check:
- System requirements
- Required tools
- Network connectivity
- DNS resolution
- Storage availability
```

### 3. OpenShift Validation

The disconnected environment requires a running OpenShift 4.18 cluster. We use the [OpenShift Agent-Based Installer](https://github.com/Red-Hat-SE-RTO/openshift-agent-install) for deployment.

1. Verify OpenShift cluster status:
```bash
# Check cluster version (should show 4.18.x)
oc get clusterversion
oc version

# Expected output:
# Client Version: 4.18.0
# Kustomize Version: v5.0.1
# Server Version: 4.18.0
# Kubernetes Version: v1.25.0

# Check nodes and cluster operators
oc get nodes
oc get co

# Expected output should show:
# - Cluster version: 4.18.x
# - Nodes: Ready
# - Cluster Operators: Available
```

2. Verify cluster networking:
```bash
# Check cluster network operator
oc get network.operator cluster -o yaml

# Check network policies
oc get networkpolicies --all-namespaces

# Verify DNS resolution
oc get dns.operator/default -o yaml
```

3. Verify storage configuration:
```bash
# Check storage classes
oc get storageclass

# Verify persistent volumes
oc get pv

# Check storage operator status
oc get csv -n openshift-storage
```

4. Check registry configuration:
```bash
# Verify internal registry status
oc get configs.imageregistry.operator.openshift.io cluster -o yaml

# Check registry pods
oc get pods -n openshift-image-registry

# Verify registry storage
oc get pvc -n openshift-image-registry
```

### 4. Configure Environment Variables
```bash
# Copy and edit the environment file
cp .env.example .env

# Required variables for OpenShift
KUBECONFIG=/path/to/kubeconfig             # Path to OpenShift kubeconfig
OPENSHIFT_PULL_SECRET="<pull-secret>"      # Your OpenShift pull secret
OPENSHIFT_VERSION="4.18"                   # OpenShift version to mirror
OPENSHIFT_MINOR_VERSION="4.18.0"           # Specific version for tools
OPENSHIFT_ARCHITECTURE="x86_64"            # Architecture for OpenShift binaries

# Required variables for Harbor Registry
HARBOR_HOSTNAME=harbor.example.com          # Your Harbor registry hostname
HARBOR_ADMIN_PASSWORD="your-secure-password" # Admin password for Harbor UI
REGISTRY_CERTIFICATE_PATH=/path/to/certs    # Path to store TLS certificates

# Optional proxy configuration (if needed)
HTTP_PROXY=http://proxy.example.com:3128
HTTPS_PROXY=http://proxy.example.com:3128
NO_PROXY=localhost,127.0.0.1,.svc,.cluster.local

# Verify environment
env | grep -E 'HARBOR|REGISTRY|KUBECONFIG|OPENSHIFT|PROXY'
```

These variables will be used by various components:
- OpenShift: Uses `OPENSHIFT_*` variables for configuration and mirroring
- Harbor Registry: Uses `HARBOR_*` variables for configuration
- TLS Certificates: Stored in `REGISTRY_CERTIFICATE_PATH`
- Proxy Settings: Used by containers and tools if configured

## Implementation Steps

Follow these guides in order to set up your disconnected environment:

1. **Environment Setup**
   - Review [Environment Setup Guide](../../environment/setup-guide.md) for detailed configuration
   - Ensure compatibility with OpenShift 4.18
   - Set up [Decision Environments](../../environment/decision-environments.md) for automation
   - Configure [Execution Environments](../../environment/execution-environments.md) for tasks

2. **Registry Setup**
   - Deploy Harbor using the [Harbor Deployment Guide](../../core/registry/deploy-harbor-podman-compose.md)
   - Configure the [Pull-through Cache](../../core/registry/pullthrough-proxy-cache-harbor.md)
   - Review [Alternative Registry Options](../../reference/alternative-implementations/deploy-jfrog-podman.md) if needed

3. **Automation Setup**
   - Deploy AAP using the [AAP Deployment Guide](../../core/automation/deploy-aap-on-openshift.md)
   - Configure [Automation Rulebooks](../../automation/rulebooks.md) for event-driven automation
   - Set up [Development Workflow](../../environment/development-workflow.md)

4. **Operations & Monitoring**
   - Implement [Deployment Operations](../../environment/deployment-operations.md)
   - Set up [Registry Monitoring](../../reference/monitoring/harbor-monitoring.md)
   - Configure [Dependency Management](../../environment/dependency-management.md)

## Troubleshooting Initial Setup

### Common Issues

1. **Tool Installation Failures**
   ```bash
   # Check system package manager
   sudo dnf clean all
   sudo dnf update
   
   # Try alternative installation methods
   # For podman/buildah:
   sudo yum module enable container-tools
   sudo yum module install container-tools
   ```

2. **Network Connectivity**
   ```bash
   # Check DNS resolution
   nslookup ${HARBOR_HOSTNAME}
   
   # Verify network routes
   ip route show
   
   # Test proxy settings (if used)
   env | grep -i proxy
   ```

3. **Storage Issues**
   ```bash
   # Check filesystem
   df -h
   
   # Verify permissions
   ls -la /var/lib/containers
   ls -la ${REGISTRY_CERTIFICATE_PATH}
   ```

4. **OpenShift Version Issues**
   ```bash
   # Verify OpenShift client and server versions match
   oc version
   
   # Check for available updates
   oc adm upgrade
   
   # View update history
   oc adm upgrade history
   
   # Check cluster operators for version-related issues
   oc get clusteroperators
   oc get clusterversion -o yaml
   ```

### Getting Help

If you encounter issues during setup:

1. Check the logs:
   ```bash
   # Validation script logs
   cat /var/log/validate-environment.log
   
   # System logs
   journalctl -xe
   ```

2. Verify system state:
   ```bash
   # SELinux status
   getenforce
   
   # Firewall rules
   sudo firewall-cmd --list-all
   ```

3. If still stuck, open an issue with:
   - Output from validate-environment.sh
   - Relevant error messages
   - Your environment details (OS version, tool versions)

## Additional Resources

- [Documentation Map](../../README.md) - Overview of all documentation
- [Architecture Decisions](../../adr/) - Understanding design choices
- [YAML Standards](../../reference/standards/yaml-standards.md) - Configuration standards

## Support

If you encounter issues:

1. Check the troubleshooting sections in each component guide
2. Review relevant component logs
3. Open an issue with:
   - Environment validation output
   - Relevant error messages
   - Steps to reproduce 