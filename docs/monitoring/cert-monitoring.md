# Certificate Monitoring Guide

## Overview

This guide covers comprehensive certificate monitoring for the disconnected OpenShift environment, including expiration monitoring, health checks, and automated rotation.

## Quick Reference

```bash
# Check certificate expiration
for cert in $(oc get secret -n harbor harbor-tls -o json | jq -r '.data."tls.crt"'); do
    echo $cert | base64 -d | openssl x509 -noout -enddate
done

# Verify certificate chain
openssl verify -CAfile ca.crt server.crt

# Monitor certificate metrics
oc get --raw /metrics | grep certificate_expiry_days
```

## Monitoring Components

### 1. Certificate Inventory

#### Harbor Registry Certificates
```bash
# List Harbor certificates
oc get secret -n harbor -l app=harbor

# Check Harbor certificate details
oc get secret harbor-tls -n harbor -o json | \
    jq -r '.data."tls.crt"' | \
    base64 -d | \
    openssl x509 -text -noout

# Monitor Harbor certificate expiry
oc exec -n harbor deployment/harbor-core -- \
    openssl s_client -connect localhost:443 2>/dev/null | \
    openssl x509 -noout -enddate
```

#### OpenShift Certificates
```bash
# List OpenShift certificates
oc get secret -n openshift-config

# Check API server certificate
oc get secret kube-apiserver-to-kubelet-signer \
    -n openshift-kube-apiserver-operator \
    -o json | \
    jq -r '.data."tls.crt"' | \
    base64 -d | \
    openssl x509 -text -noout

# Monitor service serving certificates
oc get secret -n openshift-service-ca \
    -l service.beta.openshift.io/serving-cert-secret-name
```

### 2. Certificate Metrics

#### Prometheus Metrics
```yaml
# certificate-metrics.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-metrics
  namespace: openshift-monitoring
spec:
  groups:
  - name: certificates
    rules:
    - record: certificate_expiry_days
      expr: |
        (
          cert_expiry_timestamp_seconds
          -
          time()
        ) / 86400
    - record: certificate_expiry_summary
      expr: |
        count(certificate_expiry_days < 30) by (namespace, secret)
```

#### Certificate Dashboard
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
            "title": "Certificate Expiry Overview",
            "type": "gauge",
            "targets": [
              {
                "expr": "min(certificate_expiry_days) by (namespace, secret)"
              }
            ]
          },
          {
            "title": "Certificates Expiring Soon",
            "type": "table",
            "targets": [
              {
                "expr": "certificate_expiry_days < 30"
              }
            ]
          }
        ]
      }
    }
```

### 3. Certificate Alerts

#### Alert Rules
```yaml
# certificate-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-alerts
  namespace: openshift-monitoring
spec:
  groups:
  - name: certificate-alerts
    rules:
    - alert: CertificateExpiringCritical
      expr: certificate_expiry_days < 7
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: Certificate expiring in less than 7 days
        
    - alert: CertificateExpiringWarning
      expr: certificate_expiry_days < 30
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: Certificate expiring in less than 30 days
        
    - alert: CertificateInvalid
      expr: certificate_validity_status != 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: Certificate validation failed
```

## Monitoring Scripts

### 1. Certificate Check Scripts
```bash
#!/bin/bash
# check-certificates.sh

# Check all certificates in the cluster
echo "Checking all certificates..."

# Harbor certificates
echo "Harbor certificates:"
for secret in $(oc get secret -n harbor -l app=harbor -o name); do
    echo "Checking $secret..."
    oc get $secret -n harbor -o json | \
        jq -r '.data."tls.crt"' | \
        base64 -d | \
        openssl x509 -noout -enddate
done

# OpenShift certificates
echo "OpenShift certificates:"
for secret in $(oc get secret -n openshift-config -o name | grep certificate); do
    echo "Checking $secret..."
    oc get $secret -n openshift-config -o json | \
        jq -r '.data."tls.crt"' | \
        base64 -d | \
        openssl x509 -noout -enddate
done
```

### 2. Certificate Validation Scripts
```bash
#!/bin/bash
# validate-certificates.sh

# Validate certificate chain
validate_cert_chain() {
    local cert=$1
    local ca_file=$2
    
    echo "Validating certificate chain for $cert..."
    openssl verify -CAfile $ca_file $cert
}

# Validate Harbor certificates
echo "Validating Harbor certificates..."
validate_cert_chain /etc/harbor/tls/tls.crt /etc/harbor/tls/ca.crt

# Validate OpenShift certificates
echo "Validating OpenShift certificates..."
validate_cert_chain /etc/kubernetes/ca.crt /etc/kubernetes/ca.crt
```

## Certificate Health Checks

### 1. Regular Health Checks
```bash
# Daily certificate check
./scripts/daily-cert-check.sh

# Weekly validation check
./scripts/weekly-cert-validation.sh

# Monthly expiration check
./scripts/monthly-cert-expiration.sh
```

### 2. Automated Monitoring
```bash
# Set up automated monitoring
oc apply -f certificate-metrics.yaml
oc apply -f certificate-alerts.yaml
oc apply -f certificate-dashboard.yaml
```

## Troubleshooting

### Common Issues

1. **Certificate Expiration**
   ```bash
   # Check expiration date
   openssl x509 -in cert.pem -noout -enddate
   
   # List expiring certificates
   oc get secret --all-namespaces -o json | \
       jq -r '.items[] | select(.data."tls.crt") | .data."tls.crt"' | \
       while read cert; do
           echo $cert | base64 -d | openssl x509 -noout -enddate
       done
   ```

2. **Certificate Chain Issues**
   ```bash
   # Verify certificate chain
   openssl verify -CAfile ca.crt server.crt
   
   # Check certificate details
   openssl x509 -in server.crt -text -noout
   ```

3. **Certificate Mismatch**
   ```bash
   # Compare certificates
   openssl x509 -in cert1.pem -noout -modulus | md5sum
   openssl x509 -in cert2.pem -noout -modulus | md5sum
   ```

## Best Practices

1. **Certificate Management**
   - Regular expiration checks
   - Automated monitoring
   - Documented rotation procedures
   - Secure backup storage

2. **Monitoring Configuration**
   - Set appropriate alert thresholds
   - Configure proper notification channels
   - Regular validation checks
   - Monitor certificate usage

3. **Emergency Procedures**
   - Emergency rotation plan
   - Backup certificates available
   - Quick response procedures
   - Communication plan

## Automation

### Monitoring Scripts
```bash
# Set up monitoring
./scripts/setup-cert-monitoring.sh

# Configure alerts
./scripts/configure-cert-alerts.sh

# Enable dashboards
./scripts/enable-cert-dashboards.sh
```

### Rotation Scripts
```bash
# Automated rotation
./scripts/rotate-certificates.sh

# Emergency rotation
./scripts/emergency-cert-rotation.sh

# Validation check
./scripts/validate-certificates.sh
```

## Reference

- [OpenShift Certificate Management](https://<your-domain>
- [Harbor Certificate Configuration](https://<your-domain>
- [Kubernetes Certificate Management](https://<your-domain>

## Next Steps

1. Set up [Security Monitoring](security-monitoring.md)
2. Configure [Network Monitoring](network-monitoring.md)
3. Implement [Certificate Automation](../automation/cert-automation.md)
4. Review [Certificate Alerts](certificate-alerts.md) 