# Certificate Automation Guide

## Overview

This guide covers automation of certificate management tasks in the disconnected OpenShift environment, including generation, rotation, monitoring, and validation.

## Quick Reference

```bash
# Run certificate automation
./scripts/cert-automation.sh

# Check automation status
./scripts/check-cert-automation.sh

# View automation logs
./scripts/view-cert-logs.sh
```

## Automation Components

### 1. Certificate Generation

#### Generate Certificates
```bash
#!/bin/bash
# generate-certificates.sh

# Set variables
CERT_DIR="/etc/certificates"
CONFIG_DIR="/etc/certificate-config"
LOG_FILE="/var/log/cert-generation.log"

# Function to generate CA
generate_ca() {
    local ca_config=${CONFIG_DIR}/ca-config.json
    
    # Generate CA private key
    openssl genrsa -out ${CERT_DIR}/ca.key 4096
    
    # Generate CA certificate
    openssl req -x509 -new -nodes \
        -key ${CERT_DIR}/ca.key \
        -sha256 \
        -days 3650 \
        -out ${CERT_DIR}/ca.crt \
        -config ${ca_config}
        
    echo "CA certificate generated at $(date)" >> ${LOG_FILE}
}

# Function to generate server certificate
generate_server_cert() {
    local domain=$1
    local cert_config=${CONFIG_DIR}/server-config.json
    
    # Generate private key
    openssl genrsa -out ${CERT_DIR}/${domain}.key 4096
    
    # Generate CSR
    openssl req -new \
        -key ${CERT_DIR}/${domain}.key \
        -out ${CERT_DIR}/${domain}.csr \
        -config ${cert_config}
        
    # Sign certificate
    openssl x509 -req \
        -in ${CERT_DIR}/${domain}.csr \
        -CA ${CERT_DIR}/ca.crt \
        -CAkey ${CERT_DIR}/ca.key \
        -CAcreateserial \
        -out ${CERT_DIR}/${domain}.crt \
        -days 365 \
        -sha256 \
        -extensions v3_req \
        -extfile ${cert_config}
        
    echo "Server certificate for ${domain} generated at $(date)" >> ${LOG_FILE}
}

# Generate certificates
generate_ca
generate_server_cert ${HARBOR_HOSTNAME}
```

#### Certificate Configuration
```json
// ca-config.json
{
    "signing": {
        "default": {
            "expiry": "8760h"
        },
        "profiles": {
            "server": {
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ],
                "expiry": "8760h"
            }
        }
    }
}

// server-config.json
{
    "CN": "harbor.example.com",
    "key": {
        "algo": "rsa",
        "size": 4096
    },
    "names": [
        {
            "C": "US",
            "L": "Portland",
            "O": "Harbor",
            "OU": "Harbor Registry",
            "ST": "Oregon"
        }
    ],
    "hosts": [
        "harbor.example.com",
        "harbor-core.harbor.svc",
        "harbor-registry.harbor.svc"
    ]
}
```

### 2. Certificate Rotation

#### Automated Rotation
```bash
#!/bin/bash
# rotate-certificates.sh

# Set variables
CERT_DIR="/etc/certificates"
BACKUP_DIR="/etc/certificates/backup"
LOG_FILE="/var/log/cert-rotation.log"

# Function to check expiration
check_expiration() {
    local cert=$1
    local days=$2
    
    local expiry=$(openssl x509 -in $cert -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry}" +%s)
    local now_epoch=$(date +%s)
    local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -lt $days ]; then
        return 0
    else
        return 1
    fi
}

# Function to backup certificates
backup_certificates() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p ${BACKUP_DIR}/${timestamp}
    cp -r ${CERT_DIR}/* ${BACKUP_DIR}/${timestamp}/
    echo "Certificates backed up to ${BACKUP_DIR}/${timestamp}" >> ${LOG_FILE}
}

# Function to update OpenShift
update_openshift() {
    local domain=$1
    
    # Create new secret
    oc create secret tls ${domain}-tls-new \
        --cert=${CERT_DIR}/${domain}.crt \
        --key=${CERT_DIR}/${domain}.key \
        -n harbor
        
    # Update deployment
    oc patch deployment harbor-core \
        -n harbor \
        --type=json \
        -p='[{"op": "replace", "path": "/spec/template/spec/volumes/0/secret/secretName", "value":"'${domain}'-tls-new"}]'
        
    echo "OpenShift updated with new certificates at $(date)" >> ${LOG_FILE}
}

# Main rotation process
for cert in $(find ${CERT_DIR} -name "*.crt"); do
    if check_expiration $cert 30; then
        echo "Certificate $cert needs rotation" >> ${LOG_FILE}
        backup_certificates
        ./generate-certificates.sh
        update_openshift ${HARBOR_HOSTNAME}
    fi
done
```

### 3. Certificate Monitoring

#### Monitoring Script
```bash
#!/bin/bash
# monitor-certificates.sh

# Set variables
CERT_DIR="/etc/certificates"
METRICS_FILE="/var/lib/node_exporter/cert_metrics.prom"
ALERT_LOG="/var/log/cert-alerts.log"

# Function to calculate days until expiry
get_expiry_days() {
    local cert=$1
    local expiry=$(openssl x509 -in $cert -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry}" +%s)
    local now_epoch=$(date +%s)
    echo $(( ($expiry_epoch - $now_epoch) / 86400 ))
}

# Function to generate metrics
generate_metrics() {
    # Clear existing metrics
    > ${METRICS_FILE}
    
    # Generate metrics for each certificate
    for cert in $(find ${CERT_DIR} -name "*.crt"); do
        local days_left=$(get_expiry_days $cert)
        local cert_name=$(basename $cert .crt)
        
        echo "certificate_expiry_days{cert=\"${cert_name}\"} ${days_left}" >> ${METRICS_FILE}
    done
}

# Function to check alerts
check_alerts() {
    for cert in $(find ${CERT_DIR} -name "*.crt"); do
        local days_left=$(get_expiry_days $cert)
        local cert_name=$(basename $cert .crt)
        
        if [ $days_left -lt 30 ]; then
            echo "WARNING: Certificate ${cert_name} expires in ${days_left} days" >> ${ALERT_LOG}
        fi
        
        if [ $days_left -lt 7 ]; then
            echo "CRITICAL: Certificate ${cert_name} expires in ${days_left} days" >> ${ALERT_LOG}
        fi
    done
}

# Run monitoring
generate_metrics
check_alerts
```

### 4. Certificate Validation

#### Validation Script
```bash
#!/bin/bash
# validate-certificates.sh

# Set variables
CERT_DIR="/etc/certificates"
VALIDATION_LOG="/var/log/cert-validation.log"

# Function to validate certificate
validate_certificate() {
    local cert=$1
    local ca_cert=${CERT_DIR}/ca.crt
    
    # Verify certificate chain
    if ! openssl verify -CAfile $ca_cert $cert > /dev/null 2>&1; then
        echo "ERROR: Certificate $cert failed validation" >> ${VALIDATION_LOG}
        return 1
    fi
    
    # Check key match
    local key=${cert%.*}.key
    local cert_mod=$(openssl x509 -noout -modulus -in $cert | md5sum)
    local key_mod=$(openssl rsa -noout -modulus -in $key | md5sum)
    
    if [ "$cert_mod" != "$key_mod" ]; then
        echo "ERROR: Certificate and key mismatch for $cert" >> ${VALIDATION_LOG}
        return 1
    fi
    
    echo "Certificate $cert passed validation" >> ${VALIDATION_LOG}
    return 0
}

# Validate all certificates
for cert in $(find ${CERT_DIR} -name "*.crt"); do
    validate_certificate $cert
done
```

## Automation Schedule

### Daily Tasks
```bash
# /etc/cron.daily/cert-automation
#!/bin/bash

# Monitor certificates
./scripts/monitor-certificates.sh

# Validate certificates
./scripts/validate-certificates.sh

# Generate metrics
./scripts/generate-cert-metrics.sh
```

### Weekly Tasks
```bash
# /etc/cron.weekly/cert-automation
#!/bin/bash

# Check for rotation needs
./scripts/check-cert-rotation.sh

# Generate reports
./scripts/generate-cert-report.sh

# Backup certificates
./scripts/backup-certificates.sh
```

### Monthly Tasks
```bash
# /etc/cron.monthly/cert-automation
#!/bin/bash

# Rotate certificates
./scripts/rotate-certificates.sh

# Full validation
./scripts/full-cert-validation.sh

# Audit certificate usage
./scripts/audit-cert-usage.sh
```

## Best Practices

1. **Certificate Management**
   - Use strong key lengths (4096 bits for RSA)
   - Implement automated rotation
   - Maintain secure backups
   - Document all certificates

2. **Monitoring**
   - Regular expiration checks
   - Automated alerts
   - Performance monitoring
   - Usage tracking

3. **Security**
   - Secure key storage
   - Access control
   - Audit logging
   - Incident response

## Reference

- [OpenShift Certificate Management](https://<your-domain>
- [Harbor Certificate Configuration](https://<your-domain>
- [PKI Best Practices](https://<your-domain>

## Next Steps

1. Set up [Security Automation](security-automation.md)
2. Configure [Network Automation](network-automation.md)
3. Implement [Monitoring Automation](monitoring-automation.md)
4. Review [Automation Alerts](automation-alerts.md) 