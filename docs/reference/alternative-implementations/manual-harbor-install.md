# Manual Harbor Installation Guide

This guide provides instructions for manually installing Harbor using Podman Compose. This is an alternative implementation and is **not recommended** for production use. For the recommended automated deployment, see [Deploy Harbor Registry](../../core/registry/deploy-harbor-podman-compose.md).

## Prerequisites

- RHEL 9 or compatible Linux system
- DNS record for your Harbor instance
- SSL/TLS certificates for Harbor
- Environment variables configured:
  ```bash
  HARBOR_HOSTNAME=harbor.example.com
  HARBOR_ADMIN_PASSWORD="your-secure-password"
  REGISTRY_CERTIFICATE_PATH=/path/to/certs
  ```

## Install System Packages

```bash
# Install required packages
sudo dnf install -y podman cockpit-podman python3-pip git

# Install Podman Compose
python3 -m pip install podman-compose

# Verify PATH includes /usr/local/bin
echo $PATH | grep "/usr/local/bin" || echo "export PATH=\$PATH:/usr/local/bin" >> ~/.bashrc
source ~/.bashrc

# Test Podman Compose
podman compose version

# Create Docker compatibility link
sudo ln -s /usr/bin/podman /usr/bin/docker
```

Optional: Enable Cockpit for web-based container management:
```bash
sudo systemctl enable --now cockpit.socket
# Access at https://your-server:9090
```

## Download Harbor

1. Download the offline installer:
```bash
# Create Harbor directory
sudo mkdir -p /opt/harbor-data
cd /opt

# Download and extract Harbor
wget https://<your-domain>/harbor-offline-installer-v2.12.2.tgz
tar xzvf harbor-offline-installer-v2.12.2.tgz
cd harbor
```

## Configure HTTPS

1. Prepare your certificates:
```bash
# Create certificate directory
sudo mkdir -p ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}

# Copy your certificates
sudo cp your-cert.pem ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}/server.crt
sudo cp your-key.pem ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}/server.key
```

For certificate generation options:
- Use your internal PKI
- Generate a self-signed certificate (development only)
- Use Let's Encrypt (if publicly accessible)

## Configure Harbor

1. Create configuration from template:
```bash
cp harbor.yml.tmpl harbor.yml
```

2. Configure Harbor settings:
```yaml
# The hostname to access Harbor UI and registry service
hostname: ${HARBOR_HOSTNAME}

# HTTP configuration
http:
  port: 80

# HTTPS configuration
https:
  port: 443
  certificate: ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}/server.crt
  private_key: ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}/server.key

# Data persistence
data_volume: /opt/harbor-data

# Harbor admin password
harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

# Database password (generate a secure one)
database:
  password: "generate-secure-password"

# Proxy settings (if required)
proxy:
  http_proxy: http://<your-domain>
  https_proxy: http://<your-domain>
  no_proxy: localhost,127.0.0.1,.local
  components:
    - core
    - jobservice
    - trivy
```

## Installation

1. Prepare the installer:
```bash
# Modify Docker version check
sed -i 's/^.*docker version.*exit 1.*/#&/' common.sh
```

2. Configure SELinux (temporary):
```bash
# Harbor currently has issues with SELinux
sudo setenforce 0
```

3. Modify compose file:
```bash
# Remove unsupported logging configurations
sed -i '/logging:/,/^[^ ]/d' docker-compose.yml
```

4. Run the installer:
```bash
./install.sh
```

5. Verify installation:
```bash
# Check container status
podman ps

# Access Harbor UI
echo "Access Harbor at: https://${HARBOR_HOSTNAME}"
```

## Post-Installation

1. Re-enable SELinux (recommended):
```bash
sudo setenforce 1
```

2. Configure system startup:
```bash
# Create systemd service for Podman Compose
podman generate systemd --new --name harbor > ~/.config/systemd/user/harbor.service
systemctl --user enable harbor
```

3. Test Harbor login:
```bash
podman login ${HARBOR_HOSTNAME}
```

## Troubleshooting

1. **Certificate Issues**:
```bash
# Verify certificate paths
ls -l ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}

# Check certificate validity
openssl x509 -in ${REGISTRY_CERTIFICATE_PATH}/${HARBOR_HOSTNAME}/server.crt -text -noout
```

2. **Container Issues**:
```bash
# Check container logs
podman logs harbor-core
podman logs harbor-db
```

3. **Network Issues**:
```bash
# Verify DNS resolution
dig ${HARBOR_HOSTNAME}

# Check port availability
ss -tlnp | grep -E '80|443'
``` 