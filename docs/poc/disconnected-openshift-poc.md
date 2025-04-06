# Disconnected OpenShift PoC Guide

## Overview
This guide implements a Proof of Concept (PoC) environment for a disconnected OpenShift cluster with Harbor registry, Event-Driven Ansible automation, and comprehensive monitoring. 

### Reference Architecture Documents
**Location**: `docs/adr/`
- Project Structure: `docs/adr/0001-project-structure.md`
- Registry Architecture: `docs/adr/0002-registry-architecture.md`
- Automation Framework: `docs/adr/0005-automation-framework.md`
- Monitoring and Troubleshooting: `docs/adr/0010-monitoring-troubleshooting.md`

## Step 0: Environment Setup
**Location**: `scripts/validation/`

### Prerequisites Validation
1. Hardware Requirements Check
   - Script: `scripts/validation/check-hardware.sh`
   ```bash
   # Verify hardware meets minimums
   ./scripts/validation/check-hardware.sh
   ```

2. Network Configuration
   - Script: `scripts/validation/check-network.sh`
   - Config: `config/network/network.yaml`
   ```bash
   # Verify network setup
   ./scripts/validation/check-network.sh
   ```

3. DNS Configuration
   - Script: `scripts/validation/verify-dns.sh`
   - Config: `config/dns/dns.yaml`
   ```bash
   # Verify DNS resolution
   ./scripts/validation/verify-dns.sh
   ```

## Step 1: Registry Options
**Location**: `quay/`

### 1.1 Quay Configuration
- Base Files:
  - Configuration Secret: `quay/config-secret.yml`
  - Quay Instance: `quay/quay-instance.yml`

```bash
# Deploy Quay configuration secret
oc apply -f quay/config-secret.yml

# Deploy Quay instance
oc apply -f quay/quay-instance.yml
```

### 1.2 Registry Selection
During the PoC, we have two registry options:

1. **Harbor Registry** (Default Choice):
   - Simpler deployment
   - Lighter weight
   - Sufficient for PoC testing

2. **Quay Registry** (Alternative):
   - Red Hat's enterprise registry
   - Can be deployed if enterprise features needed
   - Requires additional resources

Choose the appropriate registry based on your PoC requirements.

## Step 2: OpenShift Installation
**Location**: `playbooks/openshift/`

### 2.1 Image Mirroring
- Config: `gitops/common/image-mirrors/`
- Script: `scripts/openshift/mirror-images.sh`
```bash
# Mirror OpenShift images
./scripts/openshift/mirror-images.sh
```

### 2.2 Cluster Deployment
- Config: `config/openshift/install-config.yaml`
- Script: `scripts/openshift/deploy-cluster.sh`
```bash
# Deploy OpenShift cluster
./scripts/openshift/deploy-cluster.sh
```

## Step 3: Operator Deployment
**Location**: `gitops/operators/`

### 3.1 OpenShift Pipelines
**Location**: `tekton/`
- Base Configuration:
  - Namespace Config: `tekton/kConfig-namespace.yml`
  - Kustomization: `tekton/kustomization.yml`
  - Documentation: `tekton/README.md`

- Components:
  - Tasks: `tekton/tasks/`
    - Base Tasks
    - Custom Tasks
    - Shared Resources
  - Pipelines: `tekton/pipelines/`
    - Pipeline Definitions
    - Pipeline Resources
  - Pipeline Runs: `tekton/pipeline-runs/`
    - Example Runs
    - Templates
  - Configuration: `tekton/config/`
    - Global Settings
    - Environment Variables
  - Containers: `tekton/containers/`
    - Custom Task Containers
    - Builder Images

```bash
# Deploy Tekton base configuration
oc apply -k tekton/

# Deploy pipeline tasks
oc apply -f tekton/tasks/

# Deploy pipelines
oc apply -f tekton/pipelines/

# Deploy example pipeline runs
oc apply -f tekton/pipeline-runs/
```

### 3.2 Ansible Automation Platform
- Subscription: `gitops/operators/aap/subscription.yaml`
- Config: `gitops/operators/aap/controller.yaml`
```bash
# Deploy AAP operator
oc apply -f gitops/operators/aap/
```

## Step 4: Automation Setup
**Location**: `decision-environments/` and `rulebooks/`

### 4.1 Event-Driven Ansible
- Environment: `decision-environments/auto-mirror-image/`
- Rulebooks: `rulebooks/auto-image-mirror/`
```bash
# Deploy EDA
./scripts/automation/deploy-eda.sh
```

### 4.2 Pipeline Configuration
**Location**: `tekton/pipelines/` and `tekton/tasks/`

#### 4.2.1 Task Setup
- Base Tasks:
  ```bash
  # Deploy common tasks
  oc apply -f tekton/tasks/common/
  ```
- Custom Tasks:
  ```bash
  # Deploy custom tasks
  oc apply -f tekton/tasks/custom/
  ```

#### 4.2.2 Pipeline Setup
- Mirror Pipelines:
  ```bash
  # Deploy image mirror pipelines
  oc apply -f tekton/pipelines/mirror/
  ```
- Build Pipelines:
  ```bash
  # Deploy build pipelines
  oc apply -f tekton/pipelines/build/
  ```
- Integration Pipelines:
  ```bash
  # Deploy integration pipelines
  oc apply -f tekton/pipelines/integration/
  ```

#### 4.2.3 Pipeline Runs
- Example Runs:
  ```bash
  # Deploy example pipeline runs
  oc apply -f tekton/pipeline-runs/examples/
  ```
- Templates:
  ```bash
  # Deploy pipeline run templates
  oc apply -f tekton/pipeline-runs/templates/
  ```

#### 4.2.4 Container Setup
- Custom Containers:
  ```bash
  # Build custom task containers
  ./scripts/automation/build-task-containers.sh
  ```
- Builder Images:
  ```bash
  # Setup builder images
  ./scripts/automation/setup-builders.sh
  ```

## Step 5: GitOps Implementation
**Location**: `gitops/`
- Documentation: `gitops/README.md`

### 5.1 GitOps Structure Setup
- Base Configuration:
  - Common Resources: `gitops/common/`
  - Environment Specific: `gitops/environments/`
  - Operator Configs: `gitops/operators/`
```bash
# Initialize GitOps structure
./scripts/gitops/init-gitops.sh
```

### 5.2 ArgoCD Deployment
**Location**: `gitops/argocd/`
- Operator: `gitops/operators/argocd/subscription.yaml`
- Configuration: `gitops/argocd/config/`
- Applications: `gitops/argocd/applications/`
```bash
# Deploy ArgoCD
oc apply -f gitops/operators/argocd/
# Configure ArgoCD
oc apply -f gitops/argocd/config/
```

### 5.3 Repository Structure
**Location**: `gitops/common/`
- Image Mirrors: `gitops/common/image-mirrors/`
  - Harbor sync configurations
  - Mirror policies
- Outbound Proxy: `gitops/common/outbound-proxy/`
  - Proxy configurations
  - Network policies
- Root Certificates: `gitops/common/root-certificates/`
  - TLS certificates
  - CA bundles
```bash
# Apply common configurations
oc apply -k gitops/common/
```

### 5.4 Environment Configuration
**Location**: `gitops/environments/`
- Development: `gitops/environments/dev/`
- Production: `gitops/environments/prod/`
- Shared Services: `gitops/environments/shared/`
```bash
# Deploy environment configurations
oc apply -k gitops/environments/shared/
```

### 5.5 Application Deployment
**Location**: `gitops/applications/`
- Base Applications: `gitops/applications/base/`
- Overlays: `gitops/applications/overlays/`
```bash
# Deploy applications
oc apply -k gitops/applications/overlays/dev/
```

## Step 6: Registry Integration
**Location**: `gitops/registry/`

### 6.1 Internal Registry Setup
- Config: `gitops/registry/internal/config.yaml`
- ImageStreams: `gitops/registry/imagestreams/`
```bash
# Configure registry
oc apply -f gitops/registry/internal/
```

### 6.2 Harbor Integration
- Config: `gitops/registry/harbor/sync.yaml`
- Scripts: `scripts/registry/sync-images.sh`
```bash
# Setup Harbor sync
./scripts/registry/sync-images.sh
```

## Step 7: Monitoring Configuration
**Location**: `gitops/monitoring/`

### 7.1 Prometheus Setup
- Rules: `gitops/monitoring/prometheus/rules/`
- Config: `gitops/monitoring/prometheus/config/`
```bash
# Deploy monitoring
oc apply -f gitops/monitoring/prometheus/
```

### 7.2 Grafana Setup
- Dashboards: `gitops/monitoring/grafana/dashboards/`
- Config: `gitops/monitoring/grafana/config/`
```bash
# Deploy Grafana
oc apply -f gitops/monitoring/grafana/
```

## Step 8: Validation and Testing
**Location**: `scripts/validation/`

### 8.1 Component Testing
- Scripts: 
  - `scripts/validation/test-harbor.sh`
  - `scripts/validation/test-pipelines.sh`
  - `scripts/validation/test-automation.sh`
```bash
# Run validation suite
./scripts/validation/run-all-tests.sh
```

### 8.2 Integration Testing
- Scripts: `scripts/validation/integration-tests/`
- Config: `config/tests/integration.yaml`
```bash
# Run integration tests
./scripts/validation/run-integration-tests.sh
```

## Step 9: Maintenance Setup
**Location**: `scripts/maintenance/`

### 9.1 Backup Configuration
- Scripts: `scripts/maintenance/backup/`
- Config: `config/backup/backup.yaml`
```bash
# Configure backups
./scripts/maintenance/configure-backups.sh
```

### 9.2 Update Procedures
- Scripts: `scripts/maintenance/updates/`
- Config: `config/updates/update.yaml`
```bash
# Configure updates
./scripts/maintenance/configure-updates.sh
```

## Success Criteria Validation
**Location**: `scripts/validation/success-criteria/`

### Component Status
```bash
# Verify all components
./scripts/validation/verify-success-criteria.sh
```

## Maintenance Procedures
**Location**: `docs/maintenance/`

### Regular Tasks
- Documentation: `docs/maintenance/regular-tasks.md`
- Scripts: `scripts/maintenance/`

### Troubleshooting
- Guide: `docs/maintenance/troubleshooting.md`
- Scripts: `scripts/maintenance/troubleshooting/`

## Next Steps
**Location**: `docs/next-steps/`
1. [Security Automation](security-automation.md)
2. [Certificate Automation](cert-automation.md)
3. [Monitoring Automation](monitoring-automation.md)
4. [GitOps Configuration](../adr/0004-gitops-configuration.md)

## Registry Evaluation During PoC
**Location**: `docs/evaluation/`

### Harbor vs Quay Comparison
**Location**: `docs/evaluation/registry-comparison.md`

#### Harbor Implementation (Current)
- Advantages:
  - Open source solution
  - Lighter resource requirements
  - Simpler deployment model
  - Direct integration with FreeIPA
- Use Cases:
  - Initial PoC validation
  - Testing automation workflows
  - Development environments

#### Quay Consideration
**Location**: `playbooks/quay/`
- Enterprise Features:
  - Built-in security scanning
  - Advanced RBAC
  - Geo-replication
  - Red Hat support
- Integration Points:
  ```bash
  # Test Quay deployment
  ansible-playbook playbooks/quay/deploy-quay.yml
  ```

### Registry Migration Path
**Location**: `docs/migration/`

#### Harbor to Quay Migration
- Scripts: `scripts/migration/harbor-to-quay/`
- Documentation: `docs/migration/harbor-to-quay.md`
```bash
# Test migration procedure
./scripts/migration/test-registry-migration.sh
```

#### Production Considerations
- Documentation: `docs/evaluation/production-registry.md`
- Comparison Matrix: `docs/evaluation/registry-matrix.md`
  - Scalability requirements
  - Support requirements
  - Cost analysis
  - Integration capabilities

### Registry Testing Framework
**Location**: `tests/registry/`

#### Performance Testing
- Harbor Tests: `tests/registry/harbor/`
- Quay Tests: `tests/registry/quay/`
```bash
# Run comparison tests
./scripts/testing/compare-registry-performance.sh
```

#### Integration Testing
- Harbor Integration: `tests/registry/harbor/integration/`
- Quay Integration: `tests/registry/quay/integration/`
```bash
# Test registry integrations
./scripts/testing/test-registry-integration.sh
```

### Decision Points
**Location**: `docs/evaluation/decision-points.md`

1. Initial PoC Phase:
   - Use Harbor for rapid deployment and testing
   - Validate core workflows and automation

2. Enterprise Evaluation:
   - Test Quay deployment in parallel
   - Evaluate enterprise features
   - Assess migration requirements

3. Production Decision:
   - Compare performance metrics
   - Evaluate total cost of ownership
   - Consider support requirements
   - Assess team expertise

### Implementation Timeline
**Location**: `docs/evaluation/timeline.md`

1. Phase 1 - Harbor Implementation:
   - Current PoC validation
   - Core functionality testing
   - Integration verification

2. Phase 2 - Quay Evaluation:
   - Parallel deployment
   - Feature comparison
   - Migration testing

3. Phase 3 - Production Decision:
   - Performance analysis
   - Cost assessment
   - Support evaluation
   - Final recommendation