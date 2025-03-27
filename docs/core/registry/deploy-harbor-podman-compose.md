# Deploy Harbor Registry

This guide provides instructions for deploying Harbor as your container registry in a disconnected environment. Harbor serves as the central container registry for:
- OpenShift container images
- Custom application images
- Helm charts
- Container signing and scanning

## Deployment Methods

We support two deployment methods for Harbor:

1. **VM-based Deployment** (Recommended for Production)
   - Uses kcli to deploy Harbor on a dedicated VM
   - Provides better isolation and resource management
   - Easier backup and recovery
   - See [VM Deployment Instructions](#vm-deployment)

2. **Container-based Deployment**
   - Uses Tekton pipelines for image mirroring
   - Integrated with OpenShift CI/CD
   - See [Container Deployment Instructions](#container-deployment)

## VM Deployment

### Prerequisites

```bash
# System Requirements
✅ CPU: 4+ cores
✅ RAM: 16GB
✅ Storage: 500GB+ available
✅ Network: Access to both networks
   - Management Network for initial setup
   - Disconnected Network for air-gapped operation

# Required Tools
kcli --version
ansible --version
openssl version
```

### Deployment Steps

1. **Prepare Configuration**
   ```bash
   # Clone the repository
   git clone https://github.com/your-org/disconnected-openshift.git
   cd disconnected-openshift

   # Update harbor configuration
   cp plans/harbor.yml.example plans/harbor.yml
   vi plans/harbor.yml  # Update parameters as needed
   ```

2. **Deploy Harbor VM**
   ```bash
   # Deploy using kcli
   sudo kcli create vm -p harbor plans/harbor.yml
   ```

3. **Verify Deployment**
   ```bash
   # Check Harbor status
   curl -k https://${HARBOR_HOSTNAME}/api/v2.0/health
   
   # Test registry access
   podman login ${HARBOR_HOSTNAME}
   ```

## Container Deployment

### Prerequisites

```bash
# OpenShift cluster with Tekton installed
oc get tekton-pipelines
```

### Deployment Steps

1. **Install Required Tasks**
   ```bash
   # Apply Tekton tasks
   oc apply -f tekton/tasks/skopeo-copy-disconnected.yml
   ```

2. **Configure Authentication**
   ```bash
   # Create registry auth secret
   oc create secret generic registry-auth \
     --from-file=.dockerconfigjson=${HOME}/.docker/config.json \
     --type=kubernetes.io/dockerconfigjson
   ```

3. **Create Pipeline**
   ```bash
   # Apply pipeline definition
   oc apply -f tekton/pipelines/registry-mirror.yml
   ```

## OpenShift Integration

### 1. Configure Image Mirroring
```yaml
# Apply ImageContentSourcePolicy
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: mirror-config
spec:
  repositoryDigestMirrors:
  - mirrors:
    - ${HARBOR_HOSTNAME}/openshift/release
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - ${HARBOR_HOSTNAME}/openshift/release-art
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

### 2. Configure Trust
```bash
# Add Harbor CA to OpenShift trust bundle
oc create configmap harbor-ca \
  --from-file=ca-bundle.crt=/path/to/harbor.crt \
  -n openshift-config

oc patch proxy/cluster \
  --type=merge \
  --patch='{"spec":{"trustedCA":{"name":"harbor-ca"}}}'
```

## Verification

### 1. Test Registry Access
```bash
# Login to registry
podman login ${HARBOR_HOSTNAME}

# Pull and push test image
podman pull ubi8/ubi:latest
podman tag ubi8/ubi:latest ${HARBOR_HOSTNAME}/library/ubi:latest
podman push ${HARBOR_HOSTNAME}/library/ubi:latest
```

### 2. Verify OpenShift Integration
```bash
# Check image mirroring
oc debug node/master-0 -- chroot /host crictl images | grep ${HARBOR_HOSTNAME}

# Test pulling from Harbor
oc run test --image=${HARBOR_HOSTNAME}/library/ubi:latest
```

## Troubleshooting

### VM Deployment Issues

1. **Certificate Problems**
   ```bash
   # Regenerate certificates on Harbor VM
   ssh ubuntu@${HARBOR_HOSTNAME} "sudo openssl req -x509 -nodes -days 365 \
     -newkey rsa:2048 \
     -keyout /etc/ssl/private/harbor.key \
     -out /etc/ssl/certs/harbor.crt \
     -subj \"/CN=${HARBOR_HOSTNAME}/O=Harbor/C=US\""
   ```

2. **Service Issues**
   ```bash
   # Check Harbor service status
   ssh ubuntu@${HARBOR_HOSTNAME} "sudo systemctl status harbor"
   
   # View Harbor logs
   ssh ubuntu@${HARBOR_HOSTNAME} "sudo docker-compose -f /root/harbor/docker-compose.yml logs"
   ```

### Container Deployment Issues

1. **Pipeline Failures**
   ```bash
   # Check pipeline run status
   oc describe pipelinerun mirror-images-run

   # View task logs
   oc logs -l tekton.dev/task=skopeo-copy-disconnected
   ```

2. **Authentication Issues**
   ```bash
   # Verify secret mounted correctly
   oc describe pod -l tekton.dev/task=skopeo-copy-disconnected
   ```

## References

- [Harbor Documentation](https://goharbor.io/docs/2.10.0/)
- [OpenShift Integration Guide](../openshift/agent-installation.md)
- [Security Best Practices](../../security/README.md)
- [Tekton Documentation](https://tekton.dev/docs/)

## Next Steps

- Configure [Pull-through Cache](./pullthrough-proxy-cache-harbor.md)
- Set up [Registry Monitoring](../../reference/monitoring/harbor-monitoring.md)
- Review [Development Workflow](../../environment/development-workflow.md)

## Alternative Implementations

For the legacy VM-based deployment method, see our [VM-Based Harbor Installation Guide](../../reference/alternative-implementations/vm-harbor-install.md).