# Environment Setup Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Environment Validation](#environment-validation)
- [Python Environment](#python-environment)
- [Node.js Environment](#nodejs-environment)
- [Ansible Environment](#ansible-environment)
- [Shell Configuration](#shell-configuration)
- [Dependency Management](#dependency-management)

## Prerequisites

Before starting, ensure your system meets these requirements:

### System Requirements
```bash
# Run the environment validation script
./scripts/validate-env.sh

# Expected output:
✅ Operating System: RHEL/CentOS
✅ Python 3.9+ installed
✅ Node.js 18+ installed
✅ Ansible 2.9+ installed
✅ Bash 4.0+ installed
```

### Required Tools
```bash
# Install base dependencies
sudo dnf install -y \
  python39 \
  nodejs \
  ansible \
  git \
  podman \
  buildah \
  skopeo

# Verify installations
python3 --version
node --version
ansible --version
git --version
podman --version
```

## Environment Validation

Create a new validation script at `scripts/validate-env.sh`:

```bash
#!/bin/bash

echo "🔍 Validating Environment Setup..."

# Check OS
echo -n "Checking Operating System: "
if [[ -f /etc/redhat-release ]]; then
    echo "✅ RHEL/CentOS detected"
else
    echo "❌ Required: RHEL/CentOS"
    exit 1
fi

# Check Python
echo -n "Checking Python version: "
python3 --version | grep -q "Python 3.[9-9]"
if [[ $? -eq 0 ]]; then
    echo "✅ Python 3.9+ detected"
else
    echo "❌ Required: Python 3.9+"
    exit 1
fi

# Check Node.js
echo -n "Checking Node.js version: "
node --version | grep -q "v1[8-9]"
if [[ $? -eq 0 ]]; then
    echo "✅ Node.js 18+ detected"
else
    echo "❌ Required: Node.js 18+"
    exit 1
fi

# Check Ansible
echo -n "Checking Ansible version: "
ansible --version | grep -q "ansible [2-9]"
if [[ $? -eq 0 ]]; then
    echo "✅ Ansible 2.9+ detected"
else
    echo "❌ Required: Ansible 2.9+"
    exit 1
fi

echo "✅ Environment validation complete"
```

## Python Environment

### Virtual Environment Setup
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Verify activation
which python3
# Should show: /path/to/your/venv/bin/python3
```

### Python Dependencies
```bash
# Install dependencies
pip install -r requirements.txt

# Verify installations
pip list
```

## Node.js Environment

### Node Version Management
```bash
# Install nvm (Node Version Manager)
curl -o- https://<your-domain> | bash

# Reload shell configuration
source ~/.bashrc

# Install and use Node.js 18
nvm install 18
nvm use 18
```

### Node.js Dependencies
```bash
# Install dependencies
npm install

# Verify installations
npm list
```

## Ansible Environment

### Ansible Configuration
```bash
# Create Ansible configuration
cat << EOF > ansible.cfg
[defaults]
inventory = ./inventory
remote_user = lab-user
host_key_checking = False
roles_path = ./roles

[privilege_escalation]
become = True
become_method = sudo
EOF
```

### Ansible Collections
```bash
# Install required collections
ansible-galaxy collection install -r collections/requirements.yml

# Verify installations
ansible-galaxy collection list
```

## Shell Configuration

### Bash Profile Setup
```bash
# Add environment variables to ~/.bash_profile
cat << EOF >> ~/.bash_profile
# Project Environment Variables
export PROJECT_ROOT=\${HOME}/disconnected-openshift
export PYTHONPATH=\${PROJECT_ROOT}
export NODE_PATH=\${PROJECT_ROOT}/node_modules
export ANSIBLE_CONFIG=\${PROJECT_ROOT}/ansible.cfg
EOF

# Reload profile
source ~/.bash_profile
```

### Shell Aliases
```bash
# Add useful aliases to ~/.bashrc
cat << EOF >> ~/.bashrc
# Project Aliases
alias proj="cd \${PROJECT_ROOT}"
alias venv="source venv/bin/activate"
alias validate="./scripts/validate-env.sh"
EOF

# Reload bashrc
source ~/.bashrc
```

## Dependency Management

### Python Dependencies (requirements.txt)
```txt
# Core dependencies
ansible>=2.9.0
openshift>=0.13.1
kubernetes>=12.0.0
jinja2>=3.0.0
PyYAML>=5.4.1

# Development dependencies
pytest>=6.2.5
black>=21.5b2
flake8>=3.9.2
```

### Node.js Dependencies (package.json)
```json
{
  "dependencies": {
    "@kubernetes/client-node": "^0.18.0",
    "js-yaml": "^4.1.0"
  },
  "devDependencies": {
    "jest": "^27.0.6",
    "eslint": "^7.32.0"
  }
}
```

### Ansible Collections (collections/requirements.yml)
```yaml
---
collections:
  - name: kubernetes.core
    version: "2.3.2"
  - name: community.general
    version: "5.0.0"
  - name: ansible.posix
    version: "1.4.0"
```

## Environment Variables

Create a new environment file at `scripts/setup-env.sh`:

```bash
#!/bin/bash

# Project paths
export PROJECT_ROOT=${HOME}/disconnected-openshift
export PYTHONPATH=${PROJECT_ROOT}
export NODE_PATH=${PROJECT_ROOT}/node_modules
export ANSIBLE_CONFIG=${PROJECT_ROOT}/ansible.cfg

# Python settings
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export VIRTUAL_ENV=${PROJECT_ROOT}/venv

# Node.js settings
export NODE_ENV=development
export NPM_CONFIG_PREFIX=${PROJECT_ROOT}/.npm-global

# Ansible settings
export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3
export ANSIBLE_HOST_KEY_CHECKING=False

# Project-specific settings
export SANDBOX_DOMAIN="f2775.sandbox2933.opentlc.com"
export HARBOR_HOSTNAME="harbor.${SANDBOX_DOMAIN}"
export LAB_NETWORK_CIDR="<ip-address>/24"
export TRANS_PROXY_CIDR="<ip-address>/24"

echo "✅ Environment variables set successfully"
```

## Validation Steps

1. Run the environment validation:
```bash
./scripts/validate-env.sh
```

2. Verify Python setup:
```bash
python3 -c "import sys; print(sys.prefix)"
pip list
```

3. Verify Node.js setup:
```bash
node -e "console.log(process.versions.node)"
npm list --depth=0
```

4. Verify Ansible setup:
```bash
ansible --version
ansible-galaxy collection list
```

5. Verify environment variables:
```bash
env | grep PROJECT_ROOT
env | grep PYTHON
env | grep NODE
env | grep ANSIBLE
``` 