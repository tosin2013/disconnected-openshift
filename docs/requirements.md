# System Requirements

## Hardware Requirements

### Minimum Specifications
- **CPU:** 8+ cores
- **RAM:** 32GB+
- **Storage:** 1TB+ available
  - 500GB for OpenShift installation
  - 500GB for container images and registry

### Recommended Specifications
- **CPU:** 16+ cores
- **RAM:** 64GB+
- **Storage:** 2TB+ available
  - Allows for future growth
  - Better performance for registry operations

## Network Requirements

### Connectivity
- **Lab Network (<ip-address>/24)**
  - Used during initial setup
  - Required for installation media
  - Registry deployment

- **Trans-Proxy Network (<ip-address>/24)**
  - Used for disconnected operation
  - Internal cluster communication
  - Registry access

### Bandwidth
- **Minimum:** 1Gbps
- **Recommended:** 10Gbps
  - Especially for initial image mirroring
  - Better cluster performance

### DNS Requirements
- Forward and reverse DNS resolution
- Hostnames for:
  - Registry (e.g., harbor.example.com)
  - OpenShift API and apps wildcards
  - Load balancers

## Software Requirements

### Required Tools
```bash
# Core Tools
podman         # Container management
buildah        # Container building
skopeo         # Image copying/mirroring
ansible        # Automation

# OpenShift Tools
oc             # OpenShift CLI
tkn           # Tekton CLI

# Optional but Recommended
git            # Version control
jq             # JSON processing
yq             # YAML processing
```

### Version Requirements
- **Operating System**
  - RHEL 9.x (recommended)
  - RHEL 8.x (supported)
  - Other Linux distributions possible but not officially supported

- **Container Tools**
  ```bash
  podman >= 4.4.0
  buildah >= 1.29.0
  skopeo >= 1.11.0
  ```

- **OpenShift Tools**
  ```bash
  oc >= 4.12.0
  tkn >= 0.30.0
  ```

## Storage Configuration

### Filesystem Requirements
- XFS or ext4 filesystem
- No special mount options required
- SELinux in enforcing mode supported

### Directory Structure
```bash
/var/lib/containers/      # Container storage
/var/lib/registry/        # Registry storage
/var/lib/libvirt/images/ # VM images (if using KVM)
```

### Registry Storage
- **Minimum:** 500GB
- **Recommended:** 1TB+
- High IOPS recommended
- Regular backup capability

## Security Requirements

### Certificates
- Valid SSL certificates for:
  - Registry
  - OpenShift API
  - OpenShift apps wildcard

### Network Security
- Firewall rules for:
  - Registry ports (443/tcp)
  - OpenShift API (6443/tcp)
  - OpenShift nodes
  - Load balancers

### SELinux
- Enforcing mode supported
- Required contexts:
  ```bash
  container_file_t    # Container storage
  container_var_lib_t # Registry storage
  ```

## Validation

### Hardware Validation
```bash
# CPU cores
lscpu | grep "CPU(s):"

# Memory
free -h

# Storage
df -h
```

### Network Validation
```bash
# Network connectivity
ping <ip-address>
ping <ip-address>

# DNS resolution
nslookup harbor.example.com
nslookup api.ocp4.example.com
```

### Tool Validation
```bash
# Version checks
podman --version
buildah --version
skopeo --version
ansible --version
oc version
tkn version
```

## Troubleshooting

### Common Issues

1. **Storage Performance**
   ```bash
   # Check disk I/O
   iostat -x 1
   
   # Check filesystem type
   df -T /var/lib/containers
   ```

2. **Network Issues**
   ```bash
   # Check DNS
   dig harbor.example.com
   
   # Check connectivity
   curl -v https://<your-domain>
   ```

3. **SELinux Problems**
   ```bash
   # Check contexts
   ls -Z /var/lib/containers
   
   # Check enforcing mode
   getenforce
   ```

## Support

For issues with system requirements:
1. Run the validation script:
   ```bash
   ./scripts/validate-environment.sh
   ```
2. Check logs:
   ```bash
   journalctl -xe
   ```
3. Open an issue with:
   - Hardware specifications
   - Network configuration
   - Tool versions
   - Error messages 