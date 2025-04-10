# Decision Environments Guide

## Overview

This guide details the setup, configuration, and usage of decision environments in our disconnected OpenShift setup. Decision environments are specialized containers that provide the necessary tools and configurations for automated decision-making in image mirroring and configuration management.

## Quick Reference

```bash
# View available decision environments
podman images | grep decision-environment

# Run a decision environment
podman run -it --rm \
  -v ${PWD}:/workspace:Z \
  quay.io/example/decision-environment:latest
```

## Components

### 1. Standard Decision Environment
- Purpose: General-purpose automation decisions
- Configuration: `decision-environment.yml`
- Use cases:
  - Image mirroring decisions
  - Configuration validation
  - Dependency resolution

### 2. Minimal Decision Environment
- Purpose: Lightweight decision making
- Configuration: `minimal-decision-environment.yml`
- Use cases:
  - Basic <base64-credentials>
  - Quick verification checks

### 3. Stream Decision Environment
- Purpose: Streaming data processing decisions
- Configuration: `stream-decision-environment.yml`
- Use cases:
  - Continuous data processing
  - Real-time decision making

## Configuration

### Base Configuration
```yaml
# Example decision-environment.yml
---
version: 1
dependencies:
  python: "3.9"
  ansible:
    version: "2.9"
    collections:
      - community.general
      - ansible.posix
  system_packages:
    - git
    - jq
```

### Environment Variables
```bash
# Required Environment Variables
DECISION_ENV_TYPE=standard|minimal|stream
ANSIBLE_CONFIG=/path/to/ansible.cfg
```

## Usage Examples

### 1. Standard Decision Flow
```bash
# Run standard decision environment
./scripts/run-decision-env.sh standard

# Execute decision playbook
ansible-playbook playbooks/auto-mirror-image/decision.yml
```

### 2. Minimal Validation
```bash
# Run minimal environment for validation
./scripts/run-decision-env.sh minimal

# Perform validation
ansible-playbook playbooks/validate-config.yml
```

### 3. Stream Processing
```bash
# Run stream environment
./scripts/run-decision-env.sh stream

# Start stream processing
ansible-playbook playbooks/process-stream.yml
```

## Development

### Adding New Decision Types
1. Create new configuration file
2. Define dependencies
3. Add validation tests
4. Update documentation

### Testing
```bash
# Test decision environment
./scripts/test-decision-env.sh

# Validate configuration
./scripts/validate-decision-config.sh
```

## Troubleshooting

### Common Issues

1. **Environment Loading Failures**
```bash
# Check configuration
cat decision-environment.yml

# Validate YAML
yamllint decision-environment.yml
```

2. **Dependency Issues**
```bash
# Check Python dependencies
pip list

# Verify Ansible collections
ansible-galaxy collection list
```

3. **Permission Problems**
```bash
# Fix permissions
chmod -R u+rw .

# Check SELinux context
ls -Z
```

## Best Practices

1. **Configuration Management**
   - Version control all configurations
   - Document changes in commit messages
   - Keep configurations DRY (Don't Repeat Yourself)

2. **Security**
   - Regularly update base images
   - Scan for vulnerabilities
   - Follow principle of least privilege

3. **Performance**
   - Use minimal environments when possible
   - Clean up unused containers
   - Monitor resource usage

## References

- [Ansible Documentation](https://<your-domain>
- [Container Best Practices](https://<your-domain>
- [Python Dependencies](https://<your-domain>

## Next Steps

1. Review the [Execution Environments Guide](execution-environments.md)
2. Set up [Automation Workflows](../automation/workflows.md)
3. Configure [Monitoring](../monitoring/decision-environments.md) 