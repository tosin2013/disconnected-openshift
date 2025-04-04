# Network Security Guide

## Overview

This guide covers network security configuration and management for the disconnected OpenShift environment, including network policies, firewall rules, and secure communication between components.

## Quick Reference

```bash
# Test network connectivity
oc exec -n harbor deployment/harbor-core -- curl -k https://<your-domain>

# Apply network policy
oc apply -f network-policies/restrict-harbor-access.yaml

# View network policies
oc get networkpolicy --all-namespaces
```

## Network Architecture

### 1. Network Topology

```plaintext
[External Network]
         ↓
[Bastion Host/Jump Box] <ip-address>/24
         ↓
[OpenShift Cluster Network] <ip-address>/24
    ├── Control Plane Network
    ├── Worker Node Network
    └── Service Network
```

### 2. Network Segments

1. **External Network**
   - Corporate network
   - Internet (if required)
   - External services

2. **Management Network (<ip-address>/24)**
   - Bastion host
   - Management services
   - Monitoring systems

3. **Cluster Network (<ip-address>/24)**
   - OpenShift nodes
   - Internal services
   - Container network

## Network Policies

### 1. Default Policies

```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### 2. Harbor Registry Access

```yaml
# harbor-network-policy.yaml
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

### 3. Pipeline Network Access

```yaml
# pipeline-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-pipeline-access
  namespace: openshift-pipelines
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tekton-pipelines
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: harbor
    ports:
    - port: 8080
      protocol: TCP
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: harbor
    ports:
    - port: 443
      protocol: TCP
```

## Firewall Configuration

### 1. Required Ports

```bash
# OpenShift API
- 6443/tcp: Kubernetes API
- 22623/tcp: Machine Config Server
- 443/tcp: HTTPS
- 80/tcp: HTTP

# Cluster Communication
- 2379-2380/tcp: etcd
- 10250/tcp: Kubelet
- 10257/tcp: Controller Manager
- 10259/tcp: Scheduler

# Harbor Registry
- 443/tcp: Harbor HTTPS
- 4443/tcp: Harbor internal
```

### 2. Firewall Rules

```bash
# Allow OpenShift API access
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=22623/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=80/tcp

# Allow cluster communication
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10257/tcp
firewall-cmd --permanent --add-port=10259/tcp

# Allow Harbor access
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=4443/tcp

# Apply changes
firewall-cmd --reload
```

## Secure Communication

### 1. TLS Configuration

```yaml
# harbor-tls-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: harbor-tls-config
  namespace: harbor
data:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
<certificate-content-removed>
    # Certificate content
    -----END CERTIFICATE-----
  tls.key: "<your-key>"
    -----BEGIN PRIVATE KEY-----
<key-content-removed>
    # Private key content
    -----END PRIVATE KEY-----
```

### 2. Mutual TLS (mTLS)

```yaml
# mtls-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: harbor
spec:
  mtls:
    mode: STRICT
```

## Network Monitoring

### 1. Traffic Monitoring

```bash
# Monitor network traffic
tcpdump -i any port 443 -w capture.pcap

# Analyze traffic
wireshark capture.pcap
```

### 2. Network Metrics

```bash
# Check network latency
ping ${HARBOR_HOSTNAME}

# Monitor network bandwidth
iperf3 -c ${HARBOR_HOSTNAME}

# Check DNS resolution
dig ${HARBOR_HOSTNAME}
```

## Troubleshooting

### Common Issues

1. **Network Connectivity**
   ```bash
   # Test connectivity
   nc -zv ${HARBOR_HOSTNAME} 443
   
   # Check routes
   ip route show
   
   # DNS resolution
   nslookup ${HARBOR_HOSTNAME}
   ```

2. **Network Policy Issues**
   ```bash
   # Check policy status
   oc describe networkpolicy -n harbor
   
   # View denied connections
   oc logs -n openshift-sdn -l app=sdn
   ```

3. **TLS/Certificate Issues**
   ```bash
   # Test TLS connection
   openssl s_client -connect ${HARBOR_HOSTNAME}:443
   
   # Verify certificate
   openssl verify -CAfile ca.crt server.crt
   ```

## Best Practices

1. **Network Segmentation**
   - Implement strict network policies
   - Use separate networks for different components
   - Restrict cross-network communication
   - Monitor network boundaries

2. **Access Control**
   - Follow least privilege principle
   - Regular firewall rule review
   - Document all network access
   - Monitor unauthorized access attempts

3. **Security Monitoring**
   - Regular network scans
   - Traffic analysis
   - Security event logging
   - Intrusion detection

## Automation

### Network Scripts

```bash
# Network policy deployment
./scripts/deploy-network-policies.sh

# Firewall configuration
./scripts/configure-firewall.sh

# Network monitoring
./scripts/monitor-network.sh
```

### Security Scripts

```bash
# Security scan
./scripts/network-security-scan.sh

# Policy validation
./scripts/validate-network-policies.sh

# Certificate check
./scripts/check-certificates.sh
```

## Reference

- [OpenShift Network Security](https://<your-domain>
- [Kubernetes Network Policies](https://<your-domain>
- [Harbor Network Configuration](https://<your-domain>

## Next Steps

1. Review [Authentication Guide](authentication.md)
2. Set up [Certificate Management](certificate-guide.md)
3. Configure [Monitoring](../monitoring/network-monitoring.md)
4. Implement automated network security scanning 