# Harbor Monitoring Configuration

## Overview
This document describes how to configure monitoring for your Harbor registry deployment in a disconnected OpenShift environment.

## Monitoring Components

### 1. Harbor Internal Metrics
- Core component metrics
- Database performance
- Storage utilization
- API request metrics
- Authentication/Authorization events

### 2. Integration with OpenShift Monitoring

#### 2.1 ServiceMonitor Configuration
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: harbor-monitor
  namespace: harbor
spec:
  endpoints:
    - interval: 30s
      port: metrics
  selector:
    matchLabels:
      app: harbor
```

#### 2.2 Prometheus Configuration
- Metrics endpoint: `https://<harbor-host>:9090/metrics`
- Scrape interval: 30s
- TLS configuration required

### 3. Alert Rules

#### 3.1 Storage Alerts
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: harbor-storage-alerts
  namespace: harbor
spec:
  groups:
    - name: harbor.storage
      rules:
        - alert: HarborStorageNearlyFull
          expr: harbor_storage_free_bytes / harbor_storage_total_bytes < 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Harbor storage is nearly full"
            description: "Storage utilization is over 90%"
```

#### 3.2 Health Alerts
- Component health status
- Database connection issues
- Registry service availability
- Authentication service status

### 4. Grafana Dashboards

#### 4.1 Core Metrics Dashboard
- Request latency
- Error rates
- Storage usage trends
- Authentication success/failure rates

#### 4.2 Performance Dashboard
- API response times
- Database query performance
- Cache hit rates
- Resource utilization

## Configuration Steps

### 1. Enable Harbor Metrics
```bash
# Update Harbor configuration
harbor_metrics_enabled: true
harbor_metrics_port: 9090

# Apply configuration
ansible-playbook playbooks/harbor/configure-harbor.yml --tags metrics
```

### 2. Configure OpenShift Integration
1. Apply ServiceMonitor configuration
2. Configure Prometheus rules
3. Import Grafana dashboards

### 3. Verify Monitoring Setup
```bash
# Check metrics endpoint
curl -k https://<harbor-host>:9090/metrics

# Verify ServiceMonitor
oc get servicemonitor -n harbor

# Check Prometheus targets
oc get pods -n openshift-monitoring
oc port-forward svc/prometheus-k8s 9090:9090 -n openshift-monitoring
# Access Prometheus UI: http://localhost:9090
```

## Troubleshooting

### Common Issues
1. Metrics endpoint not accessible
   - Check Harbor configuration
   - Verify network policies
   - Validate TLS certificates

2. Missing metrics
   - Verify metrics collection is enabled
   - Check component health
   - Review Prometheus configuration

3. Alert notification issues
   - Validate alerting rules
   - Check alert manager configuration
   - Verify notification channels

## Maintenance

### 1. Regular Tasks
- Monitor storage usage trends
- Review alert history
- Update alert thresholds
- Backup dashboard configurations

### 2. Performance Tuning
- Adjust scrape intervals
- Optimize retention periods
- Fine-tune alert thresholds

## References
- [Harbor Documentation](https://<your-domain>
- [OpenShift Monitoring](https://<your-domain>
- [Prometheus Operator](https://<your-domain> 