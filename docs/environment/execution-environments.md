# Execution Environments Guide

## Overview

This guide covers the setup and management of execution environments for the disconnected OpenShift platform. Execution environments are containerized runtime environments that provide consistent, isolated spaces for running automation tasks, particularly focusing on image mirroring and binary management.

## Quick Reference

```bash
# List execution environments
podman images | grep execution-environment

# Build execution environment
podman build -t localhost/ee-auto-mirror:latest execution-environments/auto-mirror-image/

# Run execution environment
podman run -it --rm \
  -v ${PWD}:/runner:Z \
  localhost/ee-auto-mirror:latest
```

## Types of Execution Environments

### 1. Auto Mirror Image Environment
Location: `execution-environments/auto-mirror-image/`
- Purpose: Automated image mirroring operations
- Key components:
  - Skopeo for image operations
  - Authentication handlers
  - Network configuration tools

### 2. Binary Management Environment
Location: `execution-environments/binaries/`
- Purpose: OpenShift binary management
- Key components:
  - Binary verification tools
  - Checksum validators
  - Version management utilities

## Configuration

### Auto Mirror Image Environment
```yaml
# execution-environment.yml
---
version: 1
build_arg_defaults:
  EE_BASE_IMAGE: 'registry.redhat.io/ansible-automation-platform-21/ee-minimal-rhel8:latest'

dependencies:
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_galaxy:
    - ADD _build/configs/ansible.cfg /etc/ansible/ansible.cfg
  append_final:
    - RUN pip3 install --no-cache-dir skopeo-py
```

### Binary Management Environment
```yaml
# execution-environment.yml for binaries
---
version: 1
build_arg_defaults:
  EE_BASE_IMAGE: 'registry.redhat.io/ansible-automation-platform-21/ee-supported-rhel8:latest'

dependencies:
  galaxy: requirements.yml
  system:
    - tar
    - gzip
    - sha256sum
```

## Usage

### 1. Building Environments
```bash
# Build auto-mirror environment
./scripts/build-ee.sh auto-mirror-image

# Build binary management environment
./scripts/build-ee.sh binaries
```

### 2. Running Tasks
```bash
# Mirror images using auto-mirror environment
podman run -it --rm \
  -v ${PWD}:/runner:Z \
  -v ${PWD}/auth:/auth:Z \
  localhost/ee-auto-mirror:latest \
  ansible-playbook playbooks/mirror-images.yml

# Manage binaries
podman run -it --rm \
  -v ${PWD}:/runner:Z \
  localhost/ee-binaries:latest \
  ansible-playbook playbooks/manage-binaries.yml
```

## Development

### Creating New Execution Environments

1. Create directory structure:
```bash
mkdir -p execution-environments/new-environment/{_build,configs}
```

2. Create configuration files:
```bash
# execution-environment.yml
touch execution-environments/new-environment/execution-environment.yml

# Requirements
touch execution-environments/new-environment/requirements.yml
```

3. Define dependencies:
```yaml
# requirements.yml
---
collections:
  - community.general
  - ansible.posix
```

### Testing

```bash
# Test environment build
./scripts/test-ee.sh auto-mirror-image

# Validate environment
./scripts/validate-ee.sh auto-mirror-image
```

## Troubleshooting

### Common Issues

1. **Build Failures**
```bash
# Check build logs
podman logs builder-ee

# Validate configuration
yamllint execution-environment.yml
```

2. **Runtime Issues**
```bash
# Check container logs
podman logs <container_id>

# Interactive debugging
podman run -it --rm localhost/ee-auto-mirror:latest /bin/bash
```

3. **Network Problems**
```bash
# Test network connectivity
podman run --rm localhost/ee-auto-mirror:latest curl -v mirror-registry:5000

# Check DNS resolution
podman run --rm localhost/ee-auto-mirror:latest nslookup mirror-registry
```

## Best Practices

1. **Image Management**
   - Use specific versions for base images
   - Regularly update dependencies
   - Implement proper tagging strategy

2. **Security**
   - Minimize included packages
   - Scan for vulnerabilities
   - Use non-root users when possible

3. **Performance**
   - Optimize image layers
   - Clean up build artifacts
   - Use multi-stage builds when appropriate

## Maintenance

### Regular Tasks
1. Update base images monthly
2. Check for security vulnerabilities weekly
3. Validate configurations after updates
4. Test environment builds after changes

### Version Control
- Tag releases semantically
- Document changes in changelog
- Keep build history

## References

- [Ansible Builder Documentation](https://<your-domain>
- [Container Security Guide](https://<your-domain>
- [Podman Documentation](https://<your-domain>

## Next Steps

1. Configure [Automation Workflows](../automation/workflows.md)
2. Set up [Monitoring](../monitoring/execution-environments.md)
3. Review [Security Guidelines](../security/container-security.md) 