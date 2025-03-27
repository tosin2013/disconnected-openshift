# OpenShift Documentation

## Overview

This section provides comprehensive documentation for deploying and managing OpenShift 4.18 in a disconnected environment. The implementation follows [ADR-0009: OpenShift Agent Installation Strategy](../../adr/0009-openshift-agent-installation.md).

## Core Documentation

1. **Installation**
   - [Agent-Based Installation](agent-installation.md)
   - [Network Configuration](network-config.md)
   - [Storage Setup](storage-setup.md)

2. **Registry Integration**
   - [Registry Configuration](registry-config.md)
   - [Image Mirroring](image-mirroring.md)
   - [Binary Management](binary-management.md)

3. **Security**
   - [Certificate Management](security/certificates.md)
   - [Authentication Setup](security/authentication.md)
   - [Network Policies](security/network-policies.md)

4. **Monitoring**
   - [Metrics Collection](monitoring/metrics.md)
   - [Alert Configuration](monitoring/alerts.md)
   - [Dashboard Setup](monitoring/dashboards.md)

## Quick Reference

### Validation Commands
```bash
# Check cluster status
oc get clusterversion
oc get nodes
oc get co

# Verify networking
oc get network.operator cluster -o yaml
oc get networkpolicies --all-namespaces

# Check storage
oc get storageclass
oc get pv

# Monitor registry
oc get configs.imageregistry.operator.openshift.io cluster -o yaml
oc get pods -n openshift-image-registry
```

### Common Operations
```bash
# Access cluster console
oc get route console -n openshift-console

# Check cluster operators
oc get clusteroperators

# View node resources
oc adm top nodes

# Monitor cluster events
oc get events --all-namespaces --sort-by='.lastTimestamp'
```

## Implementation Steps

1. **Pre-Installation**
   - Review [Requirements](../../requirements.md)
   - Configure [Network Prerequisites](network-config.md)
   - Prepare [Storage Infrastructure](storage-setup.md)

2. **Installation**
   - Follow [Agent-Based Installation](agent-installation.md)
   - Configure [Registry Integration](registry-config.md)
   - Set up [Security Components](security/README.md)

3. **Post-Installation**
   - Implement [Monitoring](monitoring/README.md)
   - Configure [Image Mirroring](image-mirroring.md)
   - Set up [Binary Management](binary-management.md)

## Related Documentation

- [Decision Environments](../../environment/decision-environments.md)
- [Execution Environments](../../environment/execution-environments.md)
- [Harbor Registry](../registry/deploy-harbor-podman-compose.md)
- [Automation Platform](../automation/deploy-aap-on-openshift.md)

## Troubleshooting

See [OpenShift Troubleshooting Guide](troubleshooting.md) for common issues and resolutions. 