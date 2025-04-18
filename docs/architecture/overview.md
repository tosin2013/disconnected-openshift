# Architecture Overview

## System Architecture

This document provides a comprehensive overview of the disconnected OpenShift architecture and its components. For detailed decisions and rationales, refer to our [Architecture Decision Records](../adr/).

### Core Components

1. **Base Infrastructure** 
   - RHEL-based deployment environment
   - Network segmentation for disconnected operation
   - [ADR-0008: RHEL Scratch Setup](../adr/0008-rhel-scratch-setup.md)
   - [ADR-0001: Disconnected OpenShift Architecture](../adr/0001-disconnected-openshift-architecture.md)

2. **Registry Management**
   - Harbor/Quay/JFrog registry deployment
   - Pull-through cache configuration
   - Certificate management
   - [ADR-0002: Registry Management Strategy](../adr/0002-registry-management-strategy.md)

3. **Automation Pipeline**
   - Tekton pipelines for image mirroring
   - Azure DevOps integration
   - GitHub Actions workflows
   - [ADR-0003: Pipeline Automation Approach](../adr/0003-pipeline-automation-approach.md)
   - [ADR-0005: GitOps Implementation](../adr/0005-gitops-implementation.md)

4. **Security & Authentication**
   - Pull secret management
   - Certificate authorities
   - Registry authentication
   - [ADR-0004: Security Authentication Strategy](../adr/0004-security-authentication-strategy.md)

5. **Binary & Asset Management**
   - OpenShift binaries
   - RHCOS media
   - Operator bundles
   - [ADR-0006: Binary Management Strategy](../adr/0006-binary-management-strategy.md)

6. **Monitoring & Debugging**
   - Health checks
   - Logging infrastructure
   - Troubleshooting tools
   - [ADR-0007: Monitoring Debugging Strategy](../adr/0007-monitoring-debugging-strategy.md)

7. **Installation & Deployment**
   - OpenShift agent-based installation
   - KCLI provisioning
   - [ADR-0009: OpenShift Agent Installation](../adr/0009-openshift-agent-installation.md)
   - [ADR-0014: KCLI Implementation Strategy](../adr/0014-kcli-implementation-strategy.md)

8. **Testing Infrastructure**
   - Integration testing
   - Lab environment validation
   - Automated testing framework
   - [ADR-0010: Testing Infrastructure](../adr/0010-testing-infrastructure.md)
   - [ADR-0011: Lab Environment Testing](../adr/0011-lab-environment-testing.md)
   - [ADR-0012: Test Automation Framework](../adr/0012-test-automation-framework.md)
   - [ADR-0013: Project Testing Integration](../adr/0013-project-testing-integration.md)

## Implementation Flow

```mermaid
graph TD
    A[Prerequisites] -->|Setup| B[Base Infrastructure]
    B -->|Deploy| C[Registry]
    C -->|Configure| D[Authentication]
    D -->|Setup| E[Automation]
    E -->|Mirror| F[Assets]
    F -->|Install| G[OpenShift]
    G -->|Monitor| H[Operations]
```

## Component Dependencies

### Core Dependencies
- Base infrastructure requires RHEL and networking setup
- Registry deployment depends on base infrastructure
- Automation requires registry and authentication
- Asset mirroring depends on automation pipeline

### Optional Dependencies
- KCLI provisioning for automated VM deployment
- GitOps workflows for configuration management
- Pull-through cache for simplified operations

## Network Architecture

### Network Segments
1. **Lab Network (<ip-address>/24)**
   - Initial setup and deployment
   - Registry access
   - Installation media

2. **Trans-Proxy Network (<ip-address>/24)**
   - Disconnected operations
   - Cluster internal communication
   - Registry access post-setup

## Security Architecture

### Authentication Flow
1. Pull secret management
2. Registry authentication
3. Certificate distribution
4. OpenShift integration

### Certificate Management
- Custom CA integration
- Registry certificates
- OpenShift cluster certificates

## Deployment Options

### Full Disconnected
- Complete air-gapped environment
- All assets pre-mirrored
- Local update service

### Semi-Connected
- Limited internet access
- Pull-through cache
- Selective mirroring

### Proxy-Based
- HTTP proxy configuration
- SSL inspection handling
- Transparent caching

## Monitoring & Operations

### Health Checks
- Registry availability
- Pipeline status
- Mirror synchronization
- Cluster health

### Troubleshooting
- Logging infrastructure
- Debugging tools
- Common issues resolution

## Related Documentation
- [Getting Started Guide](../getting-started.md)
- [Requirements](../requirements.md)
- [Installation Examples](../../installation-examples/)
- [Post-Install Configuration](../../post-install-config/)
- [Operator Mirroring](../operator-mirroring.md)
- [Update Service Setup](../update-service.md) 