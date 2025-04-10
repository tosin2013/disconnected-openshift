# Troubleshooting Guide

## Table of Contents
- [Common Issues](#common-issues)
- [Environment Issues](#environment-issues)
- [Registry Issues](#registry-issues)
- [Pipeline Issues](#pipeline-issues)
- [Network Issues](#network-issues)
- [Diagnostic Tools](#diagnostic-tools)

## Common Issues

### ✅ Environment Variable Configuration

**Problem**: Missing or incorrect environment variables
```bash
Error: SANDBOX_DOMAIN is not set
```

**Solution**:
1. Verify environment variables are set:
```bash
# Check environment variables
env | grep SANDBOX
env | grep HARBOR
```

2. Source the environment file:
```bash
source scripts/setup-env.sh
```

### ✅ Storage Space Issues

**Problem**: Insufficient storage space for images

**Solution**:
1. Check available space:
```bash
df -h ${LIBVIRT_IMAGES}
```

2. Clean up unused images:
```bash
# List unused images
podman images --filter "dangling=true"

# Remove unused images
podman image prune -a
```

## Environment Issues

### ✅ Network Configuration

**Problem**: Unable to access Lab or Trans-Proxy networks

**Solution**:
1. Verify network connectivity:
```bash
# Test Lab Network
ping -c 1 ${LAB_NETWORK_GW}

# Test Trans-Proxy Network
ping -c 1 ${TRANS_PROXY_GW}
```

2. Check network interface configuration:
```bash
ip addr show
ip route show
```

### ✅ DNS Resolution

**Problem**: Unable to resolve hostnames

**Solution**:
1. Verify DNS configuration:
```bash
cat /etc/resolv.conf
```

2. Test DNS resolution:
```bash
nslookup ${HARBOR_HOSTNAME}
dig ${HARBOR_HOSTNAME}
```

## Registry Issues

### ✅ Harbor Access

**Problem**: Cannot access Harbor UI or API

**Solution**:
1. Check Harbor service status:
```bash
systemctl status harbor
```

2. Verify certificate configuration:
```bash
# Check certificate presence
ls -l /etc/pki/ca-trust/source/anchors/harbor.crt

# Update trust store
sudo update-ca-trust
```

### ✅ Image Push/Pull Issues

**Problem**: Unable to push or pull images

**Solution**:
1. Verify registry authentication:
```bash
podman login ${HARBOR_HOSTNAME}
```

2. Check registry connectivity:
```bash
curl -k https://<your-domain>
```

## Pipeline Issues

### ✅ Tekton Pipeline Failures

**Problem**: Pipeline tasks failing or stuck

**Solution**:
1. Check pipeline status:
```bash
oc get pipelineruns
oc get taskruns
```

2. View task logs:
```bash
tkn pipelinerun logs <pipelinerun-name>
```

### ✅ Pipeline Resource Issues

**Problem**: Missing or incorrect pipeline resources

**Solution**:
1. Verify resource existence:
```bash
oc get -n tekton-pipelines configmap,secret,serviceaccount
```

2. Check resource permissions:
```bash
oc auth can-i create pipelineruns
```

## Network Issues

### ✅ Proxy Configuration

**Problem**: Unable to access external resources through proxy

**Solution**:
1. Verify proxy settings:
```bash
env | grep -i proxy
```

2. Test proxy connectivity:
```bash
curl -x ${https_proxy} https://<your-domain>
```

### ✅ Firewall Configuration

**Problem**: Blocked network connections

**Solution**:
1. Check firewall rules:
```bash
sudo firewall-cmd --list-all
```

2. Add required ports:
```bash
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

## Diagnostic Tools

### System Health Check

Run this script to verify system health:
```bash
#!/bin/bash
echo "Running System Health Check..."

# Check CPU and Memory
echo "=== System Resources ==="
free -h
nproc
uptime

# Check Storage
echo -e "\n=== Storage Status ==="
df -h ${LIBVIRT_IMAGES}

# Check Network
echo -e "\n=== Network Status ==="
for network in "${LAB_NETWORK_GW}" "${TRANS_PROXY_GW}"; do
    ping -c 1 ${network} >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo "✅ Network ${network} accessible"
    else
        echo "❌ Network ${network} not accessible"
    fi
done

# Check Services
echo -e "\n=== Service Status ==="
systemctl is-active harbor && echo "✅ Harbor is running" || echo "❌ Harbor is not running"

# Check Registry
echo -e "\n=== Registry Status ==="
curl -k -s -o /dev/null -w "%{http_code}" https://<your-domain>
```

### Log Collection

Collect all relevant logs for troubleshooting:
```bash
#!/bin/bash
LOG_DIR="troubleshooting_logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p ${LOG_DIR}

# Collect system logs
journalctl -n 1000 > ${LOG_DIR}/system.log

# Collect Harbor logs
podman logs harbor > ${LOG_DIR}/harbor.log

# Collect pipeline logs
oc get pipelineruns -o yaml > ${LOG_DIR}/pipelineruns.yaml

# Create archive
tar czf ${LOG_DIR}.tar.gz ${LOG_DIR}
```

## Getting Help

If the above solutions don't resolve your issue:

1. Check the [documentation](../README.md)
2. Search existing issues in the repository
3. Open a new issue with:
   - Detailed description of the problem
   - Steps to reproduce
   - Relevant logs and error messages
 