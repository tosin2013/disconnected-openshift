# Dependency Management Guide

## Table of Contents
- [Overview](#overview)
- [High-Risk Dependencies](#high-risk-dependencies)
- [Dependency Patterns](#dependency-patterns)
- [Refactoring Guidelines](#refactoring-guidelines)
- [Monitoring and Maintenance](#monitoring-and-maintenance)

## Overview

Based on dependency analysis, our codebase has:
- 180 files across 8 languages/frameworks
- 133 modules with dependencies
- 3,488 total import relationships
- Primary languages: yml, .md, .py, .sh, .yaml

### Critical Modules
```bash
# Modules with highest coupling (most outgoing dependencies):
./scripts/deploy-harbor-vm.sh
./scripts/validate-environment.sh
./tekton/tasks/buildah-disconnected.yml
./tekton/tasks/skopeo-copy-disconnected.yml
./tekton/tasks/ocp-release-tools.yml
```

## High-Risk Dependencies

### Shell Script Dependencies
```bash
# Key shell scripts to monitor:
./scripts/deploy-harbor-vm.sh
./scripts/validate-environment.sh
./scripts/pull-secret-to-harbor-auth.sh
./scripts/pull-secret-to-parts.sh
./scripts/join-auths.sh

# Common issues to watch:
✅ Environment variable usage
✅ External tool dependencies
✅ File system dependencies
❌ Hardcoded paths
❌ Implicit tool versions
```

### YAML Configuration Dependencies
```yaml
# Example from tekton/tasks/buildah-disconnected.yml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: buildah-disconnected
spec:
  # Critical: These parameters are used by multiple components
  params:
    - name: REGISTRY_HOSTNAME
      type: string
    - name: REGISTRY_PATH
      type: string
  steps:
    # Dependencies on external tools and configurations
    - name: build
      image: $(params.REGISTRY_HOSTNAME)/buildah:latest
```

## Dependency Patterns

### 1. Infrastructure Dependencies
```bash
# From validate-environment.sh
# Check infrastructure dependencies:
- Network configurations (Lab + Trans-Proxy)
- Storage volumes
- Registry access
- DNS resolution
```

### 2. Tool Chain Dependencies
```bash
# From validate-environment.sh
# Required tools and versions:
- podman
- buildah
- skopeo
- ansible
```

### 3. Pipeline Dependencies
```yaml
# From tekton/tasks/skopeo-copy-disconnected.yml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: skopeo-copy-disconnected
spec:
  workspaces:
    - name: shared-workspace  # Critical shared resource
  params:
    - name: source-image
      type: string
    - name: destination-image
      type: string
```

## Refactoring Guidelines

### 1. Shell Script Modularization
Current structure:
```bash
scripts/
├── deploy-harbor-vm.sh
├── validate-environment.sh
├── join-auths.sh
├── pull-secret-to-harbor-auth.sh
└── pull-secret-to-parts.sh
```

Recommended modular structure:
```bash
scripts/
├── harbor/
│   ├── deploy.sh
│   └── configure.sh
├── auth/
│   ├── join-auths.sh
│   └── pull-secret.sh
└── validation/
    └── environment.sh
```

### 2. YAML Template Standardization
Current structure in `tekton/tasks/`:
```yaml
# Common patterns found in:
- buildah-disconnected.yml
- skopeo-copy-disconnected.yml
- ocp-release-tools.yml
```

### 3. Configuration Management
```bash
# Environment validation from validate-environment.sh
validate_environment() {
    check_required_tools
    check_network_access
    check_storage_requirements
    check_registry_access
}
```

## Monitoring and Maintenance

### 1. Environment Validation
```bash
# Run environment validation
./scripts/validate-environment.sh

# Checks performed:
✅ Required tools
✅ Network connectivity
✅ Storage availability
✅ Registry access
```

### 2. Harbor Deployment Health
```bash
# Deploy and verify Harbor
./scripts/deploy-harbor-vm.sh

# Verify Harbor access
curl -k https://<your-domain>
```

### 3. Authentication Management
```bash
# Manage registry authentication
./scripts/pull-secret-to-harbor-auth.sh
./scripts/join-auths.sh
```

## Best Practices

### 1. Dependency Documentation
```markdown
# Document all critical dependencies
## Required External Tools
- buildah
- skopeo
- podman
- ansible

## Required Services
- Harbor Registry
- DNS Server

## Required Networks
- Lab Network (<ip-address>/24)
- Trans-Proxy Network (<ip-address>/24)
```

### 2. Version Control
```yaml
# In tekton/tasks/buildah-disconnected.yml
spec:
  steps:
    - name: build
      image: $(params.REGISTRY_HOSTNAME)/buildah:stable  # Use stable tag
```

### 3. Validation Steps
```bash
# From validate-environment.sh
# Required validation steps:
1. Check tool availability
2. Verify network access
3. Validate storage
4. Test registry access
5. Verify authentication
```

## Implementation Steps

1. Environment Setup:
```bash
# Validate environment
./scripts/validate-environment.sh
```

2. Harbor Deployment:
```bash
# Deploy Harbor
./scripts/deploy-harbor-vm.sh
```

3. Authentication Setup:
```bash
# Configure authentication
./scripts/pull-secret-to-harbor-auth.sh
./scripts/join-auths.sh
```

4. Verify Setup:
```bash
# Verify all components
curl -k https://<your-domain>
podman login ${HARBOR_HOSTNAME}
``` 