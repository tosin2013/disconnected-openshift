# Development Workflow Guide

## Table of Contents
- [Development Environment](#development-environment)
- [Code Standards](#code-standards)
- [Testing Procedures](#testing-procedures)
- [Debugging Tools](#debugging-tools)
- [CI/CD Integration](#cicd-integration)
- [Common Development Tasks](#common-development-tasks)

## Development Environment

### IDE Setup
We recommend using Visual Studio Code with these extensions:
```bash
# Install recommended VS Code extensions
code --install-extension ms-python.python
code --install-extension redhat.vscode-yaml
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension hashicorp.terraform
```

### Git Configuration
```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set up Git hooks
cp scripts/hooks/* .git/hooks/
chmod +x .git/hooks/*
```

## Code Standards

### Python Standards
```bash
# Install development tools
pip install black flake8 mypy

# Format code
black .

# Run linting
flake8 .

# Run type checking
mypy .
```

### YAML Standards
```bash
# Install yamllint
pip install yamllint

# Run YAML linting
yamllint .
```

### Ansible Standards
```bash
# Install ansible-lint
pip install ansible-lint

# Run Ansible linting
ansible-lint playbooks/*
```

## Testing Procedures

### Unit Testing
```bash
# Run Python tests
pytest tests/unit

# Run Node.js tests
npm test

# Run Ansible tests
ansible-test sanity
```

### Integration Testing
```bash
# Start test environment
./scripts/start-test-env.sh

# Run integration tests
pytest tests/integration

# Clean up test environment
./scripts/cleanup-test-env.sh
```

### End-to-End Testing
```bash
# Deploy test infrastructure
./scripts/deploy-test-infra.sh

# Run E2E tests
./scripts/run-e2e-tests.sh

# Cleanup test infrastructure
./scripts/cleanup-test-infra.sh
```

## Debugging Tools

### Python Debugging
```python
# Add debugging statements
import pdb; pdb.set_trace()

# Use logging
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)
logger.debug("Debug message")
```

### Kubernetes Debugging
```bash
# Get pod logs
kubectl logs <pod-name> -n <namespace>

# Describe resource
kubectl describe <resource-type> <resource-name>

# Port forward to service
kubectl port-forward svc/<service-name> 8080:80
```

### Network Debugging
```bash
# Test connectivity
nc -zv <host> <port>

# Capture network traffic
sudo tcpdump -i any port <port>

# Check DNS resolution
dig +short <hostname>
```

## CI/CD Integration

### Local Pipeline Testing
```bash
# Install Tekton CLI
curl -LO https://<your-domain>
sudo tar xvzf tkn_0.30.0_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn

# Run pipeline locally
tkn pipeline start <pipeline-name> \
  --param="param1=value1" \
  --workspace name=shared-workspace,claimName=workspace-pvc
```

### Pipeline Development
```bash
# Create new pipeline
tkn pipeline create <pipeline-name> -f pipelines/<pipeline-name>.yaml

# Test pipeline
tkn pipeline start <pipeline-name> --dry-run

# View pipeline logs
tkn pipeline logs <pipeline-name>
```

## Common Development Tasks

### 1. Creating a New Feature
```bash
# Create feature branch
git checkout -b feature/new-feature

# Create feature directory
mkdir -p features/new-feature
touch features/new-feature/__init__.py

# Create tests
mkdir -p tests/features/new-feature
touch tests/features/new-feature/test_new_feature.py
```

### 2. Updating Dependencies
```bash
# Update Python dependencies
pip freeze > requirements.txt

# Update Node.js dependencies
npm update
npm shrinkwrap

# Update Ansible collections
ansible-galaxy collection install -r collections/requirements.yml --force
```

### 3. Running Quality Checks
```bash
#!/bin/bash
# Create quality check script

echo "Running quality checks..."

# Format code
echo "Formatting code..."
black .

# Run linting
echo "Running linters..."
flake8 .
yamllint .
ansible-lint

# Run tests
echo "Running tests..."
pytest tests/unit
npm test

# Check dependencies
echo "Checking dependencies..."
pip check
npm audit

# Run security scan
echo "Running security scan..."
bandit -r .
```

### 4. Building Documentation
```bash
# Install documentation tools
pip install sphinx sphinx-rtd-theme

# Build documentation
cd docs
make html

# Serve documentation locally
python -m http.server --directory _build/html
```

### 5. Performance Profiling
```python
# Python profiling example
import cProfile
import pstats

def profile_code():
    profiler = cProfile.Profile()
    profiler.enable()
    
    # Your code here
    
    profiler.disable()
    stats = pstats.Stats(profiler).sort_stats('cumulative')
    stats.print_stats()
```

## Environment-Specific Tasks

### Development Environment
```bash
# Start development services
docker-compose -f docker-compose.dev.yml up -d

# Watch for file changes
npm run watch

# Run development server
python manage.py runserver
```

### Testing Environment
```bash
# Set up test database
python manage.py migrate --settings=config.settings.test

# Load test data
python manage.py loaddata test_data.json

# Run test suite
pytest --environment=test
```

### Production Environment
```bash
# Build production assets
npm run build

# Collect static files
python manage.py collectstatic --noinput

# Run production checks
python manage.py check --deploy
```

## Validation Steps

1. Verify development environment:
```bash
./scripts/validate-dev-env.sh
```

2. Run all tests:
```bash
./scripts/run-all-tests.sh
```

3. Check code quality:
```bash
./scripts/check-code-quality.sh
```

4. Verify documentation:
```bash
./scripts/build-docs.sh
```

5. Test deployment:
```bash
./scripts/test-deployment.sh
``` 