# Security Monitoring Guide

## Overview

This guide covers comprehensive security monitoring for the disconnected OpenShift environment, including audit logging, alerts, and compliance monitoring.

## Quick Reference

```bash
# View security events
oc get events --field-selector reason=SecurityViolation

# Check audit logs
oc adm node-logs --role=master --path=oauth-server/audit.log

# Monitor compliance
oc get compliancescans
```

## Monitoring Components

### 1. Audit Logging

#### OpenShift Audit Logs
```bash
# View API server audit logs
oc adm node-logs --role=master --path=kube-apiserver/audit.log

# View OAuth server audit logs
oc adm node-logs --role=master --path=oauth-server/audit.log

# View registry audit logs
oc logs -f deployment/image-registry -n openshift-image-registry
```

#### Harbor Audit Logs
```bash
# View Harbor core logs
oc logs -f deployment/harbor-core -n harbor

# View Harbor auth logs
oc logs -f deployment/harbor-auth -n harbor

# Export audit logs
oc exec deployment/harbor-core -n harbor -- \
    curl -X GET "/api/v2.0/audit-logs" \
    -H "accept: application/json"
```

### 2. Security Alerts

#### Alert Configuration
```yaml
# security-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: security-alerts
  namespace: openshift-monitoring
spec:
  groups:
  - name: security
    rules:
    - alert: UnauthorizedAccess
      expr: rate(authentication_failed_total[5m]) > 10
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: High rate of authentication failures
        
    - alert: CertificateExpiringSoon
      expr: certificate_expiry_days < 30
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: Certificate expiring soon
        
    - alert: SuspiciousNetworkActivity
      expr: rate(network_policy_violations_total[5m]) > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: Suspicious network activity detected
```

#### Alert Routing
```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: openshift-monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'security-team'
      routes:
      - match:
          severity: critical
        receiver: 'security-team'
    receivers:
    - name: 'security-team'
      email_configs:
      - to: 'security@example.com'
```

### 3. Compliance Monitoring

#### Compliance Operator Setup
```yaml
# compliance-operator.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: compliance-operator
  namespace: openshift-compliance
spec:
  channel: "release-0.1"
  name: compliance-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

#### Compliance Scan
```yaml
# compliance-scan.yaml
apiVersion: compliance.openshift.io/v1alpha1
kind: ComplianceScan
metadata:
  name: rhcos4-e8
spec:
  profile: xccdf_org.ssgproject.content_profile_e8
  content: ssg-rhcos4-ds.xml
  contentImage: quay.io/complianceascode/ocp4:latest
```

## Monitoring Dashboards

### 1. Security Overview Dashboard
```yaml
# security-dashboard.yaml
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDashboard
metadata:
  name: security-overview
  namespace: openshift-monitoring
spec:
  json: |
    {
      "dashboard": {
        "panels": [
          {
            "title": "Authentication Failures",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(authentication_failed_total[5m])"
              }
            ]
          },
          {
            "title": "Network Policy Violations",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(network_policy_violations_total[5m])"
              }
            ]
          }
        ]
      }
    }
```

### 2. Certificate Dashboard
```yaml
# certificate-dashboard.yaml
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDashboard
metadata:
  name: certificate-monitoring
  namespace: openshift-monitoring
spec:
  json: |
    {
      "dashboard": {
        "panels": [
          {
            "title": "Certificate Expiry Days",
            "type": "gauge",
            "targets": [
              {
                "expr": "certificate_expiry_days"
              }
            ]
          }
        ]
      }
    }
```

## Monitoring Scripts

### 1. Security Check Scripts
```bash
#!/bin/bash
# security-check.sh

# Check authentication failures
echo "Checking authentication failures..."
oc get events --field-selector reason=FailedAuth

# Check network policy violations
echo "Checking network policy violations..."
oc get events --field-selector reason=NetworkPolicyViolation

# Check certificate expiration
echo "Checking certificate expiration..."
for cert in $(oc get secret -n harbor harbor-tls -o json | jq -r '.data."tls.crt"'); do
    echo $cert | base64 -d | openssl x509 -noout -enddate
done
```

### 2. Compliance Check Scripts
```bash
#!/bin/bash
# compliance-check.sh

# Run compliance scan
echo "Running compliance scan..."
oc create -f compliance-scan.yaml

# Wait for scan completion
while [[ $(oc get compliancescan rhcos4-e8 -o jsonpath='{.status.phase}') != "DONE" ]]; do
    echo "Waiting for scan completion..."
    sleep 30
done

# Get scan results
echo "Scan results:"
oc get compliancecheckresults
```

## Troubleshooting

### Common Issues

1. **Missing Audit Logs**
   ```bash
   # Check audit log configuration
   oc get configmap config -n openshift-kube-apiserver -o yaml
   
   # Verify log paths
   oc debug node/<master-node> -- chroot /host ls -l /var/log/audit/
   ```

2. **Alert Manager Issues**
   ```bash
   # Check alert manager status
   oc get pods -n openshift-monitoring | grep alertmanager
   
   # View alert manager logs
   oc logs -f alertmanager-main-0 -n openshift-monitoring
   ```

3. **Compliance Operator Issues**
   ```bash
   # Check operator status
   oc get csv -n openshift-compliance
   
   # View operator logs
   oc logs -f deployment/compliance-operator -n openshift-compliance
   ```

## Best Practices

1. **Audit Logging**
   - Enable comprehensive audit logging
   - Regularly review audit logs
   - Set up log rotation
   - Archive logs securely

2. **Alert Configuration**
   - Set appropriate thresholds
   - Configure proper routing
   - Test alert delivery
   - Document alert responses

3. **Compliance Monitoring**
   - Regular compliance scans
   - Track compliance trends
   - Document exceptions
   - Plan remediation

## Automation

### Monitoring Scripts
```bash
# Daily security check
./scripts/daily-security-check.sh

# Weekly compliance scan
./scripts/weekly-compliance-scan.sh

# Monthly audit review
./scripts/monthly-audit-review.sh
```

### Report Generation
```bash
# Generate security report
./scripts/generate-security-report.sh

# Generate compliance report
./scripts/generate-compliance-report.sh

# Generate audit summary
./scripts/generate-audit-summary.sh
```

## Reference

- [OpenShift Monitoring](https://<your-domain>
- [OpenShift Compliance Operator](https://<your-domain>
- [Harbor Auditing](https://<your-domain>

## Next Steps

1. Set up [Certificate Monitoring](cert-monitoring.md)
2. Configure [Network Monitoring](network-monitoring.md)
3. Implement [Security Automation](../automation/security-automation.md)
4. Review [Security Alerts](security-alerts.md) 