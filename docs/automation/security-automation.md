# Security Automation Guide

## Overview

This guide covers automation of security tasks in the disconnected OpenShift environment, including certificate management, authentication, and security monitoring.

## Quick Reference

```bash
# Run security automation
./scripts/security-automation.sh

# Check automation status
./scripts/check-automation-status.sh

# View automation logs
./scripts/view-automation-logs.sh
```

## Automation Components

### 1. Certificate Automation

#### Certificate Rotation
```bash
#!/bin/bash
# rotate-certificates.sh

# Set variables
CERT_DIR="/etc/certificates"
BACKUP_DIR="/etc/certificates/backup"
LOG_FILE="/var/log/cert-rotation.log"

# Function to backup certificates
backup_certificates() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p ${BACKUP_DIR}/${timestamp}
    cp -r ${CERT_DIR}/* ${BACKUP_DIR}/${timestamp}/
    echo "Certificates backed up to ${BACKUP_DIR}/${timestamp}" >> ${LOG_FILE}
}

# Function to generate new certificates
generate_certificates() {
    # Generate CA
    openssl genrsa -out ${CERT_DIR}/ca.key 4096
    openssl req -x509 -new -nodes \
        -key ${CERT_DIR}/ca.key \
        -sha256 \
        -days 1024 \
        -out ${CERT_DIR}/ca.crt \
        -subj "/CN=Local CA"

    # Generate server certificate
    openssl genrsa -out ${CERT_DIR}/server.key 4096
    openssl req -new \
        -key ${CERT_DIR}/server.key \
        -out ${CERT_DIR}/server.csr \
        -subj "/CN=${HARBOR_HOSTNAME}"
    
    openssl x509 -req \
        -in ${CERT_DIR}/server.csr \
        -CA ${CERT_DIR}/ca.crt \
        -CAkey ${CERT_DIR}/ca.key \
        -CAcreateserial \
        -out ${CERT_DIR}/server.crt \
        -days 365 \
        -sha256
}

# Function to update OpenShift
update_openshift() {
    # Update Harbor certificates
    oc create secret tls harbor-tls-new \
        --cert=${CERT_DIR}/server.crt \
        --key=${CERT_DIR}/server.key \
        -n harbor

    # Update cluster trust
    oc create configmap harbor-ca-new \
        --from-file=ca-bundle.crt=${CERT_DIR}/ca.crt \
        -n openshift-config

    # Apply changes
    oc patch deployment harbor-core \
        -n harbor \
        --type=json \
        -p='[{"op": "replace", "path": "/spec/template/spec/volumes/0/secret/secretName", "value":"harbor-tls-new"}]'
}

# Main rotation process
echo "Starting certificate rotation at $(date)" >> ${LOG_FILE}
backup_certificates
generate_certificates
update_openshift
echo "Certificate rotation completed at $(date)" >> ${LOG_FILE}
```

#### Certificate Monitoring
```bash
#!/bin/bash
# monitor-certificates.sh

# Set variables
ALERT_DAYS=30
EMAIL_RECIPIENT="security@example.com"

# Function to check certificate expiration
check_expiration() {
    local cert=$1
    local expiry=$(openssl x509 -in $cert -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry}" +%s)
    local now_epoch=$(date +%s)
    local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -lt $ALERT_DAYS ]; then
        echo "Certificate $cert expires in $days_left days" | \
            mail -s "Certificate Expiration Alert" ${EMAIL_RECIPIENT}
    fi
}

# Monitor all certificates
for cert in $(find /etc/certificates -name "*.crt"); do
    check_expiration $cert
done
```

### 2. Authentication Automation

#### User Management
```bash
#!/bin/bash
# manage-users.sh

# Set variables
USER_FILE="/etc/user-management/users.yaml"
AUDIT_LOG="/var/log/user-management.log"

# Function to create user
create_user() {
    local username=$1
    local password=$2
    
    # Create HTPasswd entry
    htpasswd -b /etc/htpasswd ${username} ${password}
    
    # Create OpenShift resources
    oc create user ${username}
    oc create identity htpasswd:${username}
    oc create useridentitymapping htpasswd:${username} ${username}
    
    echo "User ${username} created at $(date)" >> ${AUDIT_LOG}
}

# Function to delete user
delete_user() {
    local username=$1
    
    # Remove HTPasswd entry
    htpasswd -D /etc/htpasswd ${username}
    
    # Remove OpenShift resources
    oc delete user ${username}
    oc delete identity htpasswd:${username}
    
    echo "User ${username} deleted at $(date)" >> ${AUDIT_LOG}
}

# Process user management file
while IFS=: read -r action username password; do
    case $action in
        create)
            create_user $username $password
            ;;
        delete)
            delete_user $username
            ;;
    esac
done < ${USER_FILE}
```

#### Access Review
```bash
#!/bin/bash
# review-access.sh

# Set variables
REVIEW_LOG="/var/log/access-review.log"
EMAIL_RECIPIENT="security@example.com"

# Function to review user access
review_access() {
    local username=$1
    
    # Get user roles
    local roles=$(oc get rolebinding,clusterrolebinding -o json | \
        jq -r '.items[] | select(.subjects[].name=="'$username'") | .roleRef.name')
    
    # Check last login
    local last_login=$(oc get user $username -o json | \
        jq -r '.metadata.annotations."openshift.io/user-last-login"')
    
    # Report findings
    echo "User: $username" >> ${REVIEW_LOG}
    echo "Roles: $roles" >> ${REVIEW_LOG}
    echo "Last Login: $last_login" >> ${REVIEW_LOG}
    echo "---" >> ${REVIEW_LOG}
}

# Review all users
for user in $(oc get users -o name); do
    review_access $user
done

# Send report
cat ${REVIEW_LOG} | mail -s "Access Review Report" ${EMAIL_RECIPIENT}
```

### 3. Security Monitoring Automation

#### Security Checks
```bash
#!/bin/bash
# security-checks.sh

# Set variables
CHECK_LOG="/var/log/security-checks.log"
ALERT_LOG="/var/log/security-alerts.log"

# Function to check security status
check_security() {
    # Check certificate status
    echo "Checking certificates..." >> ${CHECK_LOG}
    ./scripts/check-certificates.sh >> ${CHECK_LOG}
    
    # Check authentication status
    echo "Checking authentication..." >> ${CHECK_LOG}
    ./scripts/check-authentication.sh >> ${CHECK_LOG}
    
    # Check network policies
    echo "Checking network policies..." >> ${CHECK_LOG}
    ./scripts/check-network-policies.sh >> ${CHECK_LOG}
}

# Function to process alerts
process_alerts() {
    # Check for critical issues
    if grep -q "CRITICAL" ${CHECK_LOG}; then
        echo "Critical security issues found at $(date)" >> ${ALERT_LOG}
        cat ${CHECK_LOG} | mail -s "Critical Security Alert" ${EMAIL_RECIPIENT}
    fi
    
    # Check for warnings
    if grep -q "WARNING" ${CHECK_LOG}; then
        echo "Security warnings found at $(date)" >> ${ALERT_LOG}
        cat ${CHECK_LOG} | mail -s "Security Warning" ${EMAIL_RECIPIENT}
    fi
}

# Run security checks
check_security
process_alerts
```

#### Compliance Automation
```bash
#!/bin/bash
# compliance-automation.sh

# Set variables
COMPLIANCE_LOG="/var/log/compliance.log"
REPORT_DIR="/var/reports/compliance"

# Function to run compliance scan
run_compliance_scan() {
    # Create compliance scan
    oc apply -f - <<EOF
apiVersion: compliance.openshift.io/v1alpha1
kind: ComplianceScan
metadata:
  name: rhcos4-e8
spec:
  profile: xccdf_org.ssgproject.content_profile_e8
  content: ssg-rhcos4-ds.xml
  contentImage: quay.io/complianceascode/ocp4:latest
EOF

    # Wait for scan completion
    while [[ $(oc get compliancescan rhcos4-e8 -o jsonpath='{.status.phase}') != "DONE" ]]; do
        sleep 30
    done
    
    # Generate report
    oc get compliancecheckresult -o json > ${REPORT_DIR}/compliance-report.json
}

# Function to process results
process_results() {
    # Count failures
    local failures=$(jq '.items[] | select(.status=="FAIL") | .metadata.name' ${REPORT_DIR}/compliance-report.json | wc -l)
    
    # Generate summary
    echo "Compliance scan completed at $(date)" >> ${COMPLIANCE_LOG}
    echo "Total failures: $failures" >> ${COMPLIANCE_LOG}
    
    # Send report
    if [ $failures -gt 0 ]; then
        cat ${COMPLIANCE_LOG} | mail -s "Compliance Failures Detected" ${EMAIL_RECIPIENT}
    fi
}

# Run compliance automation
run_compliance_scan
process_results
```

## Automation Schedule

### Daily Tasks
```bash
# /etc/cron.daily/security-automation
#!/bin/bash

# Certificate monitoring
./scripts/monitor-certificates.sh

# Security checks
./scripts/security-checks.sh

# Log rotation
./scripts/rotate-security-logs.sh
```

### Weekly Tasks
```bash
# /etc/cron.weekly/security-automation
#!/bin/bash

# Access review
./scripts/review-access.sh

# Compliance scan
./scripts/compliance-automation.sh

# Report generation
./scripts/generate-security-report.sh
```

### Monthly Tasks
```bash
# /etc/cron.monthly/security-automation
#!/bin/bash

# Certificate rotation
./scripts/rotate-certificates.sh

# Full security audit
./scripts/security-audit.sh

# Policy review
./scripts/review-security-policies.sh
```

## Best Practices

1. **Automation Management**
   - Version control all scripts
   - Test in staging environment
   - Document dependencies
   - Monitor automation logs

2. **Error Handling**
   - Implement proper error handling
   - Set up alerting for failures
   - Create rollback procedures
   - Log all actions

3. **Security Considerations**
   - Secure script permissions
   - Use service accounts
   - Encrypt sensitive data
   - Audit automation access

## Reference

- [OpenShift Security Automation](https://<your-domain>
- [Kubernetes Security Tools](https://<your-domain>
- [Compliance Operator](https://<your-domain>

## Next Steps

1. Set up [Certificate Automation](cert-automation.md)
2. Configure [Network Automation](network-automation.md)
3. Implement [Monitoring Automation](monitoring-automation.md)
4. Review [Automation Alerts](automation-alerts.md) 