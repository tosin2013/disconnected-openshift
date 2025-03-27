# Documentation Guide

## Overview

This documentation provides comprehensive guidance for setting up and managing a disconnected OpenShift environment. Each section aligns with our [Architecture Decision Records](adr/) and provides practical implementation details.

## Core Documentation

### Getting Started
- [Requirements](requirements.md) - System and environment requirements
- [Getting Started Guide](getting-started.md) - Initial setup walkthrough
- [Environment Setup](environment/setup-guide.md) - Detailed environment configuration

### Architecture & Design
- [System Architecture](architecture/overview.md) - High-level system design
- [System Integration](system-integration.md) - Component integration details
- [Disconnected Environment Plan](disconnected-environment-plan.md) - Planning guide

### Registry Management
- [Harbor Deployment](harbor/deployment.md) - Harbor registry setup
- [Harbor Monitoring](harbor-monitoring.md) - Registry monitoring
- [Pull-through Cache (Harbor)](pullthrough-proxy-cache-harbor.md) - Harbor cache setup
- [Pull-through Cache (JFrog)](pullthrough-proxy-cache-jfrog.md) - JFrog cache setup

### Pipeline & Automation
- [Pipeline Setup](pipeline/setup.md) - Pipeline configuration
- [Tekton Setup](tekton-setup.md) - Tekton installation and configuration
- [Workflow Guide](workflow.md) - Development and deployment workflows

### Environment Management
- [Development Workflow](environment/development-workflow.md) - Developer guide
- [Deployment Operations](environment/deployment-operations.md) - Operations guide
- [Dependency Management](environment/dependency-management.md) - Managing dependencies

## Missing Documentation (TODO)

### Security (ADR-0004)
- [ ] security/certificate-guide.md - Certificate management
- [ ] security/security-guide.md - Security best practices
- [ ] security/authentication.md - Authentication setup

### GitOps (ADR-0005)
- [ ] gitops/setup.md - GitOps configuration
- [ ] gitops/workflow.md - GitOps workflows
- [ ] gitops/best-practices.md - Best practices

### Binary Management (ADR-0006)
- [ ] binary-management/mirroring.md - Binary mirroring
- [ ] binary-management/updates.md - Update management
- [ ] binary-management/verification.md - Binary verification

### Monitoring (ADR-0007)
- [ ] monitoring/setup.md - Monitoring configuration
- [ ] monitoring/alerts.md - Alert configuration
- [ ] monitoring/dashboards.md - Dashboard setup

### Installation (ADR-0009)
- [ ] installation/agent-based.md - Agent installation
- [ ] installation/troubleshooting.md - Installation issues
- [ ] installation/validation.md - Installation validation

### KCLI (ADR-0014)
- [ ] kcli/setup.md - KCLI installation
- [ ] kcli/usage.md - KCLI usage guide
- [ ] kcli/automation.md - Automation with KCLI

## Documentation Standards

All documentation should follow our [YAML Standards](yaml-standards.md) and maintain consistent formatting. For documentation generation guidelines, see [Documentation Generation](documentation-generation.md).

## Contributing

To contribute to the documentation:

1. Check the "Missing Documentation" section above
2. Review relevant ADRs in [adr/](adr/)
3. Follow our documentation standards
4. Submit a pull request

## Documentation Map

```mermaid
graph TD
    A[Getting Started] --> B[Environment Setup]
    B --> C[Registry Setup]
    B --> D[Pipeline Setup]
    C --> E[Operations]
    D --> E
    E --> F[Monitoring]
    
    G[Security] -.-> C
    G -.-> D
    H[GitOps] -.-> E
    I[KCLI] -.-> B
    
    style G stroke-dasharray: 5 5
    style H stroke-dasharray: 5 5
    style I stroke-dasharray: 5 5
```

Legend:
- Solid lines: Existing documentation
- Dashed lines: Planned documentation 