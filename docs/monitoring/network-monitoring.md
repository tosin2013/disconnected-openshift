# Network Monitoring Guide

## Overview

This guide covers comprehensive network monitoring for the disconnected OpenShift environment, including traffic monitoring, network policies, and performance metrics.

## Quick Reference

```bash
# Check network policies
oc get networkpolicy --all-namespaces

# Monitor network traffic
oc exec -n openshift-sdn $(oc get pods -n openshift-sdn -l app=sdn -o name | head -1) -- tcpdump -i any

# View network metrics
oc get --raw /metrics | grep network
```

## Monitoring Components

### 1. Network Traffic Monitoring

#### OpenShift SDN Monitoring
```bash
# Monitor SDN traffic
oc exec -n openshift-sdn $(oc get pods -n openshift-sdn -l app=sdn -o name | head -1) -- \
    tcpdump -i any -w capture.pcap

# Analyze traffic
oc exec -n openshift-sdn $(oc get pods -n openshift-sdn -l app=sdn -o name | head -1) -- \
    tcpdump -r capture.pcap -n

# Monitor specific ports
oc exec -n openshift-sdn $(oc get pods -n openshift-sdn -l app=sdn -o name | head -1) -- \
    tcpdump -i any port 443
```

#### Harbor Registry Traffic
```bash
# Monitor Harbor traffic
oc exec -n harbor deployment/harbor-core -- \
    tcpdump -i any port 443

# Check Harbor connections
oc exec -n harbor deployment/harbor-core -- \
    netstat -an | grep ESTABLISHED

# Monitor registry requests
oc logs -f deployment/harbor-registry -n harbor
```

### 2. Network Metrics

#### Prometheus Metrics
```yaml
# network-metrics.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-metrics
  namespace: openshift-monitoring
spec:
  groups:
  - name: network
    rules:
    - record: network_transmit_bytes_total
      expr: |
        sum(rate(container_network_transmit_bytes_total[5m])) by (namespace)
    - record: network_receive_bytes_total
      expr: |
        sum(rate(container_network_receive_bytes_total[5m])) by (namespace)
    - record: network_errors_total
      expr: |
        sum(rate(container_network_receive_errors_total[5m] + 
        container_network_transmit_errors_total[5m])) by (namespace)
```

#### Network Dashboard
```yaml
# network-dashboard.yaml
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDashboard
metadata:
  name: network-monitoring
  namespace: openshift-monitoring
spec:
  json: |
    {
      "dashboard": {
        "panels": [
          {
            "title": "Network Traffic Overview",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_network_transmit_bytes_total[5m])) by (namespace)"
              },
              {
                "expr": "sum(rate(container_network_receive_bytes_total[5m])) by (namespace)"
              }
            ]
          },
          {
            "title": "Network Errors",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_network_receive_errors_total[5m])) by (namespace)"
              }
            ]
          }
        ]
      }
    }
```

### 3. Network Policy Monitoring

#### Policy Metrics
```yaml
# policy-metrics.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-policy-metrics
  namespace: openshift-monitoring
spec:
  groups:
  - name: networkpolicy
    rules:
    - record: network_policy_violations_total
      expr: |
        sum(increase(network_policy_violations_total[5m])) by (namespace, policy_name)
```

#### Policy Alerts
```yaml
# policy-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-policy-alerts
  namespace: openshift-monitoring
spec:
  groups:
  - name: networkpolicy
    rules:
    - alert: NetworkPolicyViolation
      expr: rate(network_policy_violations_total[5m]) > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: High rate of network policy violations
        
    - alert: NetworkErrorSpike
      expr: rate(container_network_errors_total[5m]) > 100
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: Spike in network errors detected
```

## Monitoring Scripts

### 1. Network Check Scripts
```bash
#!/bin/bash
# check-network.sh

# Check network connectivity
echo "Checking network connectivity..."

# Test internal services
echo "Testing internal services..."
for svc in $(oc get svc --all-namespaces -o name); do
    echo "Testing $svc..."
    oc get $svc --all-namespaces -o json | \
        jq -r '.items[].spec.clusterIP' | \
        xargs -I {} ping -c 1 {}
done

# Test external connectivity
echo "Testing external connectivity..."
ping -c 1 ${HARBOR_HOSTNAME}

# Check DNS resolution
echo "Testing DNS resolution..."
for svc in $(oc get svc --all-namespaces -o name); do
    echo "Resolving $svc..."
    oc get $svc --all-namespaces -o json | \
        jq -r '.items[].metadata.name' | \
        xargs -I {} nslookup {}.svc.cluster.local
done
```

### 2. Policy Validation Scripts
```bash
#!/bin/bash
# validate-policies.sh

# Check network policies
echo "Checking network policies..."
oc get networkpolicy --all-namespaces -o yaml

# Validate policy configuration
echo "Validating policy configuration..."
for policy in $(oc get networkpolicy --all-namespaces -o name); do
    echo "Validating $policy..."
    oc describe $policy
done

# Test policy enforcement
echo "Testing policy enforcement..."
for ns in $(oc get ns -o name); do
    echo "Testing namespace $ns..."
    oc run test-pod --image=busybox --restart=Never \
        --command -- wget -q -O- http://<your-domain>
done
```

## Network Health Checks

### 1. Regular Health Checks
```bash
# Daily network check
./scripts/daily-network-check.sh

# Weekly policy validation
./scripts/weekly-policy-validation.sh

# Monthly performance check
./scripts/monthly-performance-check.sh
```

### 2. Automated Monitoring
```bash
# Set up monitoring
oc apply -f network-metrics.yaml
oc apply -f network-dashboard.yaml
oc apply -f policy-alerts.yaml
```

## Troubleshooting

### Common Issues

1. **Network Connectivity**
   ```bash
   # Test connectivity
   oc exec test-pod -- ping -c 1 harbor-core.harbor.svc
   
   # Check routes
   oc get route -n harbor
   
   # Test DNS
   oc exec test-pod -- nslookup harbor-core.harbor.svc
   ```

2. **Policy Issues**
   ```bash
   # Check policy status
   oc describe networkpolicy -n harbor
   
   # View policy logs
   oc logs -n openshift-sdn -l app=sdn
   
   # Test policy
   oc run test --image=busybox --rm -it -- wget -q harbor-core.harbor.svc
   ```

3. **Performance Issues**
   ```bash
   # Check network metrics
   oc get --raw /metrics | grep network
   
   # Monitor bandwidth
   oc exec test-pod -- iperf3 -c harbor-core.harbor.svc
   
   # Check latency
   oc exec test-pod -- ping -c 10 harbor-core.harbor.svc
   ```

## Best Practices

1. **Traffic Monitoring**
   - Regular traffic analysis
   - Baseline establishment
   - Anomaly detection
   - Performance tracking

2. **Policy Management**
   - Regular policy review
   - Least privilege access
   - Policy documentation
   - Change tracking

3. **Performance Monitoring**
   - Regular benchmarking
   - Capacity planning
   - Bottleneck identification
   - Trend analysis

## Automation

### Monitoring Scripts
```bash
# Set up monitoring
./scripts/setup-network-monitoring.sh

# Configure alerts
./scripts/configure-network-alerts.sh

# Enable dashboards
./scripts/enable-network-dashboards.sh
```

### Analysis Scripts
```bash
# Traffic analysis
./scripts/analyze-traffic.sh

# Policy analysis
./scripts/analyze-policies.sh

# Performance analysis
./scripts/analyze-performance.sh
```

## Reference

- [OpenShift Network Monitoring](https://<your-domain>
- [Kubernetes Network Policies](https://<your-domain>
- [Network Observability](https://<your-domain>

## Next Steps

1. Set up [Security Monitoring](security-monitoring.md)
2. Configure [Certificate Monitoring](cert-monitoring.md)
3. Implement [Network Automation](../automation/network-automation.md)
4. Review [Network Alerts](network-alerts.md) 