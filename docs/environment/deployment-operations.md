# Deployment and Operations Guide

## Table of Contents
- [Deployment Prerequisites](#deployment-prerequisites)
- [Environment Setup](#environment-setup)
- [Deployment Procedures](#deployment-procedures)
- [Monitoring and Logging](#monitoring-and-logging)
- [Maintenance Tasks](#maintenance-tasks)
- [Troubleshooting](#troubleshooting)

## Deployment Prerequisites

### Infrastructure Requirements
```bash
# Verify system resources
./scripts/check-resources.sh

# Expected minimum requirements:
✅ CPU: 8 cores
✅ Memory: 32GB RAM
✅ Storage: 1TB available
✅ Network: 10Gbps connectivity
```

### Network Configuration
```bash
# Verify network connectivity
./scripts/check-network.sh

# Required network access:
✅ Lab Network (<ip-address>/24)
✅ Trans-Proxy Network (<ip-address>/24)
✅ Internet access for initial setup
```

## Environment Setup

### SSL Certificate Setup
```bash
# Generate self-signed certificates
./scripts/generate-certs.sh

# Expected output:
✅ Generated: /etc/pki/ca-trust/source/anchors/harbor.crt
✅ Generated: /etc/pki/ca-trust/source/anchors/harbor.key
```

### DNS Configuration
```bash
# Configure DNS records
./scripts/configure-dns.sh

# Verify DNS resolution
for host in harbor registry mirror; do
    dig +short ${host}.${SANDBOX_DOMAIN}
done
```

## Deployment Procedures

### 1. Initialize Infrastructure
```bash
# Deploy base infrastructure
./scripts/deploy-infra.sh

# Expected components:
✅ Virtual networks configured
✅ Storage volumes provisioned
✅ Security groups configured
```

### 2. Deploy Harbor Registry
```bash
# Deploy Harbor
./scripts/deploy-harbor.sh

# Verify deployment
curl -k https://<your-domain>

# Configure registry
./scripts/configure-harbor.sh \
    --admin-password "${HARBOR_ADMIN_PASSWORD}" \
    --storage-size "500Gi"
```

### 3. Configure Image Mirroring
```bash
# Set up image mirroring
./scripts/setup-mirror.sh

# Test mirroring
./scripts/test-mirror.sh \
    --source "quay.io/openshift-release-dev/ocp-release:4.12.0-x86_64" \
    --destination "${HARBOR_HOSTNAME}/openshift/release:4.12.0"
```

### 4. Deploy OpenShift
```bash
# Initialize OpenShift deployment
./scripts/deploy-openshift.sh \
    --version "4.12.0" \
    --node-count 3 \
    --registry "${HARBOR_HOSTNAME}"

# Verify deployment
oc get nodes
oc get co
```

## Monitoring and Logging

### System Monitoring
```bash
# Deploy monitoring stack
./scripts/deploy-monitoring.sh

# Components deployed:
✅ Prometheus
✅ Grafana
✅ AlertManager
✅ Node Exporter
```

### Log Collection
```bash
# Configure log aggregation
./scripts/setup-logging.sh

# Verify logging
./scripts/verify-logs.sh \
    --components "harbor,registry,openshift" \
    --time-range "24h"
```

### Alerts Configuration
```yaml
# alerts/registry-alerts.yml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: registry-alerts
spec:
  groups:
  - name: registry.rules
    rules:
    - alert: RegistryHighUsage
      expr: harbor_storage_used / harbor_storage_total > 0.85
      for: 10m
      labels:
        severity: warning
      annotations:
        description: "Registry storage usage above 85%"
```

## Maintenance Tasks

### 1. Backup Procedures
```bash
# Backup critical components
./scripts/backup.sh \
    --components "harbor,registry,certificates" \
    --destination "/backup/$(date +%Y%m%d)"

# Verify backup
./scripts/verify-backup.sh --latest
```

### 2. Update Procedures
```bash
# Update Harbor
./scripts/update-harbor.sh \
    --version "2.8.0" \
    --backup true

# Update OpenShift
./scripts/update-openshift.sh \
    --version "4.12.1" \
    --batch-size 1
```

### 3. Health Checks
```bash
# Run health checks
./scripts/health-check.sh

# Checks performed:
✅ Certificate validity
✅ Storage usage
✅ Service status
✅ Network connectivity
✅ Resource usage
```

### 4. Cleanup Tasks
```bash
# Clean up old images
./scripts/cleanup-images.sh \
    --older-than "90d" \
    --exclude-tags "latest,stable"

# Clean up old backups
./scripts/cleanup-backups.sh \
    --older-than "30d" \
    --keep-last 5
```

## Troubleshooting

### Common Issues

#### 1. Registry Access Issues
```bash
# Check registry status
curl -k https://<your-domain>

# Check authentication
podman login ${HARBOR_HOSTNAME}

# Verify certificates
openssl verify -CAfile /etc/pki/ca-trust/source/anchors/harbor.crt \
    /etc/pki/ca-trust/source/anchors/harbor.crt
```

#### 2. Network Issues
```bash
# Check network connectivity
for network in "${LAB_NETWORK_GW}" "${TRANS_PROXY_GW}"; do
    ping -c 1 ${network} >/dev/null 2>&1 && \
        echo "✅ ${network} accessible" || \
        echo "❌ ${network} not accessible"
done

# Check DNS resolution
for host in harbor registry mirror; do
    dig +short ${host}.${SANDBOX_DOMAIN} || \
        echo "❌ DNS resolution failed for ${host}"
done
```

#### 3. Storage Issues
```bash
# Check storage usage
df -h ${LIBVIRT_IMAGES}

# Check volume status
lvs
vgs
pvs
```

### Diagnostic Tools

#### 1. System Diagnostics
```bash
# Collect system diagnostics
./scripts/collect-diagnostics.sh \
    --components "all" \
    --time-range "24h" \
    --output "diagnostics-$(date +%Y%m%d)"
```

#### 2. Log Analysis
```bash
# Analyze logs for errors
./scripts/analyze-logs.sh \
    --components "harbor,registry" \
    --severity "error" \
    --time-range "1h"
```

#### 3. Performance Analysis
```bash
# Check system performance
./scripts/check-performance.sh

# Components checked:
✅ CPU usage
✅ Memory usage
✅ Disk I/O
✅ Network throughput
```

## Validation Steps

1. Verify deployment status:
```bash
./scripts/verify-deployment.sh
```

2. Check component health:
```bash
./scripts/check-health.sh
```

3. Test functionality:
```bash
./scripts/test-functionality.sh
```

4. Verify monitoring:
```bash
./scripts/verify-monitoring.sh
```

5. Test backup/restore:
```bash
./scripts/test-backup-restore.sh
``` 