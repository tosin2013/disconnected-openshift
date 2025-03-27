# Certificate Management Guide

## Overview

This guide provides detailed instructions for managing certificates in a disconnected OpenShift environment. It covers certificate generation, distribution, rotation, and troubleshooting.

## Quick Reference

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 \
    -keyout harbor.key \
    -out harbor.crt \
    -days 365 \
    -nodes \
    -subj "/CN=${HARBOR_HOSTNAME}"

# Add certificate to OpenShift
oc create configmap custom-ca \
    --from-file=ca-bundle.crt=/path/to/ca.crt \
    -n openshift-config

# Update cluster trust bundle
oc patch proxy/cluster \
    --type=merge \
    --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'
```

## Certificate Requirements

### Harbor Registry
- TLS certificate (public key)
- Private key
- CA certificate chain
- Supported formats: PEM

### OpenShift Cluster
- API server certificate
- Ingress certificate
- Service serving certificates
- etcd certificates

### Additional Components
- Monitoring certificates
- Logging certificates
- Custom operator certificates

## Certificate Management

### 1. Generate Certificates

#### Self-Signed Certificates
```bash
# Generate CA key and certificate
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes \
    -key ca.key \
    -sha256 \
    -days 1024 \
    -out ca.crt \
    -subj "/CN=Local CA"

# Generate server key
openssl genrsa -out server.key 4096

# Generate CSR
openssl req -new \
    -key server.key \
    -out server.csr \
    -config <(cat <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]
CN = ${HARBOR_HOSTNAME}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HARBOR_HOSTNAME}
DNS.2 = *.${HARBOR_HOSTNAME}
EOF
)

# Sign certificate
openssl x509 -req \
    -in server.csr \
    -CA ca.crt \
    -CAkey ca.key \
    -CAcreateserial \
    -out server.crt \
    -days 365 \
    -sha256 \
    -extensions v3_req
```

#### Using Commercial Certificates
1. Generate CSR using the template above
2. Submit to certificate authority
3. Receive signed certificate and chain
4. Verify certificate chain
   ```bash
   openssl verify -CAfile ca-chain.crt server.crt
   ```

### 2. Deploy Certificates

#### Harbor Registry
```bash
# Create Harbor namespace
oc create namespace harbor

# Create TLS secret
oc create secret tls harbor-tls \
    --cert=server.crt \
    --key=server.key \
    -n harbor

# Create CA configmap
oc create configmap harbor-ca \
    --from-file=ca.crt=ca.crt \
    -n harbor
```

#### OpenShift Configuration
```bash
# Add CA to cluster trust bundle
oc create configmap custom-ca \
    --from-file=ca-bundle.crt=ca.crt \
    -n openshift-config

# Update cluster proxy configuration
oc patch proxy/cluster \
    --type=merge \
    --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'

# Update image registry configuration
oc patch image.config.openshift.io/cluster \
    --type=merge \
    --patch='{"spec":{"additionalTrustedCA":{"name":"custom-ca"}}}'
```

### 3. Certificate Rotation

#### Planned Rotation
```bash
# 1. Generate new certificates
./scripts/generate-certificates.sh

# 2. Create new secrets
oc create secret tls harbor-tls-new \
    --cert=new-server.crt \
    --key=new-server.key \
    -n harbor

# 3. Update Harbor deployment
oc set volume deployment/harbor-core \
    --add \
    --name=harbor-tls \
    --mount-path=/etc/harbor/tls \
    --secret-name=harbor-tls-new

# 4. Restart Harbor pods
oc rollout restart deployment/harbor-core
```

#### Emergency Rotation
```bash
# 1. Generate emergency certificates
./scripts/generate-emergency-certs.sh

# 2. Replace existing secrets
oc create secret tls harbor-tls \
    --cert=emergency-server.crt \
    --key=emergency-server.key \
    -n harbor \
    --dry-run=client -o yaml | \
    oc replace -f -

# 3. Force restart all affected pods
oc delete pods --all -n harbor
```

## Certificate Validation

### 1. Verify Certificate Installation
```bash
# Check certificate in OpenShift
oc get configmap custom-ca -n openshift-config -o yaml

# Verify Harbor certificate
openssl s_client -connect ${HARBOR_HOSTNAME}:443 -showcerts

# Test Harbor registry
curl -v --cacert ca.crt https://${HARBOR_HOSTNAME}/v2/
```

### 2. Monitor Certificate Health
```bash
# Check certificate expiration
for cert in $(oc get secret -n harbor harbor-tls -o json | jq -r '.data."tls.crt"'); do
    echo $cert | base64 -d | openssl x509 -noout -enddate
done

# Monitor certificate-related events
oc get events -n harbor | grep -i certificate

# Check certificate-related pod logs
oc logs -f deployment/harbor-core -n harbor | grep -i certificate
```

## Troubleshooting

### Common Issues

1. **Certificate Trust Issues**
   ```bash
   # Update system trust store
   cp ca.crt /etc/pki/ca-trust/source/anchors/
   update-ca-trust extract

   # Verify trust
   openssl verify -CAfile /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
       server.crt
   ```

2. **Certificate Mismatch**
   ```bash
   # Compare certificates
   openssl x509 -in server.crt -noout -text
   openssl s_client -connect ${HARBOR_HOSTNAME}:443 | \
       openssl x509 -noout -text
   ```

3. **Certificate Chain Issues**
   ```bash
   # Verify chain
   openssl verify -CAfile ca-chain.crt server.crt

   # Check chain order
   openssl crl2pkcs7 -nocrl -certfile ca-chain.crt | \
       openssl pkcs7 -print_certs -noout
   ```

## Automation

### Certificate Management Scripts
```bash
# Generate certificates
./scripts/generate-certificates.sh

# Deploy certificates
./scripts/deploy-certificates.sh

# Rotate certificates
./scripts/rotate-certificates.sh

# Monitor certificates
./scripts/monitor-certificates.sh
```

### Integration with External Systems
```bash
# Vault integration example
vault write pki/issue/harbor \
    common_name=${HARBOR_HOSTNAME} \
    ttl=8760h

# Let's Encrypt example
certbot certonly \
    --manual \
    --preferred-challenges=dns \
    -d ${HARBOR_HOSTNAME}
```

## Best Practices

1. **Certificate Management**
   - Use appropriate key lengths (RSA 4096, ECC P-384)
   - Set reasonable validity periods
   - Implement automated rotation
   - Maintain backup copies

2. **Security Considerations**
   - Protect private keys
   - Use secure storage
   - Implement least privilege access
   - Monitor certificate usage

3. **Operational Procedures**
   - Document all certificate locations
   - Maintain certificate inventory
   - Schedule regular reviews
   - Test rotation procedures

## Reference

- [OpenShift Certificate Management](https://<your-domain>
- [Harbor Certificate Configuration](https://<your-domain>
- [PKI Best Practices](https://<your-domain>

## Next Steps

1. Review [Security Guide](security-guide.md)
2. Set up [Authentication](authentication.md)
3. Configure automated certificate monitoring
4. Implement certificate rotation procedures 