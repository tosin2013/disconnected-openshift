# Automation Rulebooks Guide

## Overview

This guide covers the automation rulebooks used in our disconnected OpenShift environment. Rulebooks define event-driven automation rules that handle various aspects of the system, particularly focusing on image mirroring and system monitoring.

## Quick Reference

```bash
# List available rulebooks
ls rulebooks/*/rulebook.yml

# Validate rulebook syntax
ansible-rulebook --rulebook rulebooks/auto-image-mirror/rulebook.yml --check

# Run a rulebook
ansible-rulebook --rulebook rulebooks/auto-image-mirror/rulebook.yml -i inventory.yml
```

## Rulebook Types

### 1. Auto Image Mirror Rulebook
Location: `rulebooks/auto-image-mirror/rulebook.yml`

Purpose: Automates the process of detecting and mirroring new container images.

```yaml
---
- name: Auto Image Mirror Rules
  hosts: all
  sources:
    - name: registry_watch
      ansible.eda.watch_registry:
        registry: "quay.io"
        repository: "openshift-release-dev/ocp-release"
        polling_period: 300
  rules:
    - name: New Image Available
      condition: event.type == "new_image"
      action:
        run_playbook:
          name: playbooks/auto-mirror-image/main.yml
```

### 2. Prometheus Alert Rules
Location: `rulebooks/auto-image-mirror/prometheusRule.yml`

Purpose: Defines monitoring and alerting rules for the mirroring process.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mirror-alerts
  namespace: openshift-monitoring
spec:
  groups:
    - name: mirror.rules
      rules:
        - alert: MirrorJobFailed
          expr: mirror_job_status == 0
          for: 5m
          labels:
            severity: critical
```

## Configuration

### Requirements
```yaml
# requirements.yml
---
collections:
  - ansible.eda
  - community.general
  - kubernetes.core
```

### Environment Variables
```bash
# Required for rulebook execution
export ANSIBLE_RULEBOOK_WEBHOOK_PORT=5000
export ANSIBLE_RULEBOOK_URL=http://localhost:5000
```

## Usage Examples

### 1. Running Rulebooks
```bash
# Start the rulebook daemon
ansible-rulebook-daemon --rulebook rulebooks/auto-image-mirror/rulebook.yml

# Monitor rulebook execution
ansible-rulebook-ctl status
```

### 2. Testing Rules
```bash
# Test rule conditions
ansible-rulebook-ctl test-condition \
  --condition "event.type == 'new_image'" \
  --event '{"type": "new_image", "image": "test:latest"}'

# Validate actions
ansible-rulebook-ctl test-action \
  --action "run_playbook" \
  --vars "playbook=test.yml"
```

### 3. Managing Rules
```bash
# List active rules
ansible-rulebook-ctl list

# Disable specific rule
ansible-rulebook-ctl disable-rule "New Image Available"

# Enable specific rule
ansible-rulebook-ctl enable-rule "New Image Available"
```

## Development

### Creating New Rulebooks

1. Create directory structure:
```bash
mkdir -p rulebooks/new-rulebook
touch rulebooks/new-rulebook/{rulebook.yml,requirements.yml}
```

2. Define basic structure:
```yaml
---
- name: New Rulebook
  hosts: all
  sources:
    - name: source_name
      source_type: source_plugin
  rules:
    - name: rule_name
      condition: event.type == "condition"
      action:
        run_playbook:
          name: playbook.yml
```

### Testing

```bash
# Syntax check
ansible-rulebook --rulebook new-rulebook.yml --check

# Dry run
ansible-rulebook --rulebook new-rulebook.yml --print-events
```

## Troubleshooting

### Common Issues

1. **Source Plugin Errors**
```bash
# Check source plugin status
ansible-rulebook-ctl source-status

# Debug source plugin
export ANSIBLE_RULEBOOK_DEBUG=1
ansible-rulebook --rulebook rulebook.yml
```

2. **Rule Execution Problems**
```bash
# View rule execution logs
ansible-rulebook-ctl logs

# Check rule statistics
ansible-rulebook-ctl stats
```

3. **Integration Issues**
```bash
# Verify connectivity
curl -v ${ANSIBLE_RULEBOOK_URL}/health

# Check integration status
ansible-rulebook-ctl check-integration
```

## Best Practices

1. **Rule Design**
   - Keep conditions simple and specific
   - Use meaningful rule names
   - Document expected behaviors
   - Include error handling

2. **Performance**
   - Optimize polling intervals
   - Use efficient conditions
   - Monitor resource usage
   - Implement rate limiting

3. **Maintenance**
   - Version control rulebooks
   - Document changes
   - Test before deployment
   - Monitor rule effectiveness

## Monitoring

### Prometheus Integration
```yaml
# prometheusRule.yml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: rulebook-monitoring
spec:
  groups:
    - name: rulebook.rules
      rules:
        - alert: RulebookNotRunning
          expr: rulebook_status == 0
          for: 5m
          labels:
            severity: critical
```

### Metrics
- Rule execution count
- Action success rate
- Source plugin health
- Processing time

## References

- [Ansible Rulebook Documentation](https://<your-domain>
- [Event-Driven Ansible](https://<your-domain>
- [Prometheus Operator](https://<your-domain>

## Next Steps

1. Set up [Monitoring Integration](../monitoring/rulebook-monitoring.md)
2. Configure [Alert Management](../monitoring/alert-management.md)
3. Review [Security Guidelines](../security/automation-security.md) 