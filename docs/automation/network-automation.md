# Network Automation Guide

## Overview

This guide covers automation of network management tasks in the disconnected OpenShift environment, including policy management, monitoring, and troubleshooting.

## Quick Reference

```bash
# Run network automation
./scripts/network-automation.sh

# Check automation status
./scripts/check-network-automation.sh

# View automation logs
./scripts/view-network-logs.sh
```

## Automation Components

### 1. Network Policy Management

#### Policy Deployment
```bash
#!/bin/bash
# deploy-policies.sh

# Set variables
POLICY_DIR="/etc/network-policies"
LOG_FILE="/var/log/policy-deployment.log"

# Function to validate policy
validate_policy() {
    local policy=$1
    
    if ! oc create -f $policy --dry-run=client -o yaml > /dev/null 2>&1; then
        echo "ERROR: Policy $policy validation failed" >> ${LOG_FILE}
        return 1
    fi
    return 0
}

# Function to deploy policy
deploy_policy() {
    local policy=$1
    local namespace=$(yq eval '.metadata.namespace' $policy)
    
    # Create namespace if it doesn't exist
    oc get namespace $namespace || oc create namespace $namespace
    
    # Apply policy
    oc apply -f $policy
    echo "Policy $policy deployed at $(date)" >> ${LOG_FILE}
}

# Deploy all policies
for policy in $(find ${POLICY_DIR} -name "*.yaml"); do
    if validate_policy $policy; then
        deploy_policy $policy
    fi
done
```

#### Policy Templates
```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: ${NAMESPACE}
spec:
  podSelector: {}
  policyTypes:
  - Ingress

# allow-harbor.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-harbor-access
  namespace: harbor
spec:
  podSelector:
    matchLabels:
      app: harbor
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-pipelines
    ports:
    - port: 443
      protocol: TCP
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-pipelines
    ports:
    - port: 443
      protocol: TCP
```

### 2. Network Monitoring

#### Traffic Monitoring
```bash
#!/bin/bash
# monitor-traffic.sh

# Set variables
METRICS_DIR="/var/lib/node_exporter"
LOG_FILE="/var/log/traffic-monitoring.log"

# Function to capture traffic metrics
capture_metrics() {
    local namespace=$1
    local pod=$2
    
    # Get pod traffic metrics
    local rx_bytes=$(oc exec $pod -n $namespace -- cat /sys/class/net/eth0/statistics/rx_bytes)
    local tx_bytes=$(oc exec $pod -n $namespace -- cat /sys/class/net/eth0/statistics/tx_bytes)
    
    # Write to metrics file
    echo "pod_network_receive_bytes{namespace=\"$namespace\",pod=\"$pod\"} $rx_bytes" >> ${METRICS_DIR}/network.prom
    echo "pod_network_transmit_bytes{namespace=\"$namespace\",pod=\"$pod\"} $tx_bytes" >> ${METRICS_DIR}/network.prom
}

# Function to monitor namespace traffic
monitor_namespace() {
    local namespace=$1
    
    # Get all pods in namespace
    for pod in $(oc get pods -n $namespace -o name); do
        capture_metrics $namespace $pod
    done
}

# Monitor all namespaces
for ns in $(oc get namespaces -o name); do
    monitor_namespace $ns
done
```

#### Performance Monitoring
```bash
#!/bin/bash
# monitor-performance.sh

# Set variables
METRICS_FILE="/var/lib/node_exporter/network_performance.prom"
LOG_FILE="/var/log/performance-monitoring.log"

# Function to test latency
test_latency() {
    local target=$1
    local namespace=$2
    
    # Run ping test
    local latency=$(oc exec -n $namespace deploy/test-pod -- ping -c 5 $target | \
        grep "avg" | awk -F "/" '{print $5}')
    
    echo "network_latency_ms{target=\"$target\",namespace=\"$namespace\"} $latency" >> ${METRICS_FILE}
}

# Function to test bandwidth
test_bandwidth() {
    local target=$1
    local namespace=$2
    
    # Run iperf test
    local bandwidth=$(oc exec -n $namespace deploy/test-pod -- iperf3 -c $target -t 5 | \
        grep "sender" | awk '{print $7}')
    
    echo "network_bandwidth_mbps{target=\"$target\",namespace=\"$namespace\"} $bandwidth" >> ${METRICS_FILE}
}

# Test network performance
for target in ${HARBOR_HOSTNAME} "kubernetes.default.svc"; do
    test_latency $target "default"
    test_bandwidth $target "default"
done
```

### 3. Network Troubleshooting

#### Automated Diagnostics
```bash
#!/bin/bash
# network-diagnostics.sh

# Set variables
DIAGNOSTIC_DIR="/var/log/network-diagnostics"
LOG_FILE="/var/log/network-diagnostics.log"

# Function to check DNS
check_dns() {
    local service=$1
    local namespace=$2
    
    # Test DNS resolution
    if ! oc exec -n $namespace deploy/test-pod -- nslookup $service > /dev/null 2>&1; then
        echo "ERROR: DNS resolution failed for $service" >> ${LOG_FILE}
        return 1
    fi
    return 0
}

# Function to check connectivity
check_connectivity() {
    local target=$1
    local namespace=$2
    
    # Test network connectivity
    if ! oc exec -n $namespace deploy/test-pod -- curl -s -o /dev/null $target; then
        echo "ERROR: Connectivity failed to $target" >> ${LOG_FILE}
        return 1
    fi
    return 0
}

# Function to collect diagnostics
collect_diagnostics() {
    local namespace=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local dir=${DIAGNOSTIC_DIR}/${namespace}/${timestamp}
    
    mkdir -p $dir
    
    # Collect network policies
    oc get networkpolicy -n $namespace -o yaml > ${dir}/network-policies.yaml
    
    # Collect pod networking info
    for pod in $(oc get pods -n $namespace -o name); do
        oc exec $pod -n $namespace -- ip addr show > ${dir}/${pod}-ip.txt
        oc exec $pod -n $namespace -- netstat -an > ${dir}/${pod}-netstat.txt
    done
    
    # Collect SDN logs
    oc logs -n openshift-sdn -l app=sdn --tail=1000 > ${dir}/sdn-logs.txt
}

# Run diagnostics
for ns in $(oc get namespaces -o name); do
    if ! check_dns "kubernetes.default.svc" $ns || \
       ! check_connectivity "https://${HARBOR_HOSTNAME}" $ns; then
        collect_diagnostics $ns
    fi
done
```

## Automation Schedule

### Daily Tasks
```bash
# /etc/cron.daily/network-automation
#!/bin/bash

# Monitor network traffic
./scripts/monitor-traffic.sh

# Check network policies
./scripts/check-policies.sh

# Generate metrics
./scripts/generate-network-metrics.sh
```

### Weekly Tasks
```bash
# /etc/cron.weekly/network-automation
#!/bin/bash

# Performance testing
./scripts/test-network-performance.sh

# Policy validation
./scripts/validate-network-policies.sh

# Generate reports
./scripts/generate-network-report.sh
```

### Monthly Tasks
```bash
# /etc/cron.monthly/network-automation
#!/bin/bash

# Full network audit
./scripts/network-audit.sh

# Policy review
./scripts/review-network-policies.sh

# Performance baseline
./scripts/baseline-network-performance.sh
```

## Best Practices

1. **Policy Management**
   - Use policy templates
   - Regular policy validation
   - Document changes
   - Test before deployment

2. **Monitoring**
   - Regular performance checks
   - Traffic analysis
   - Alert configuration
   - Trend analysis

3. **Troubleshooting**
   - Automated diagnostics
   - Log collection
   - Root cause analysis
   - Documentation

## Reference

- [OpenShift Network Management](https://<your-domain>
- [Kubernetes Network Policies](https://<your-domain>
- [Network Troubleshooting](https://<your-domain>

## Next Steps

1. Set up [Security Automation](security-automation.md)
2. Configure [Certificate Automation](cert-automation.md)
3. Implement [Monitoring Automation](monitoring-automation.md)
4. Review [Automation Alerts](automation-alerts.md) 