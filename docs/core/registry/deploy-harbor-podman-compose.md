# Deploy Harbor Registry

This guide provides instructions for deploying Harbor as your container registry in a disconnected environment. For initial setup requirements, see the [Getting Started Guide](../getting-started/getting-started.md).

## Automated Deployment

We provide an automated deployment script that handles the complete Harbor setup:

```bash
# Deploy Harbor using the automated script
./scripts/deploy-harbor-vm.sh
```

This script will:
1. Create a VM with proper specifications:
   - Memory: 16GB
   - CPUs: 4
   - Storage: 500GB
   - Network: Configured with static IP and DNS

2. Run Ansible playbooks to:
   - Install Harbor base components
   - Configure binary storage
   - Set up release image handling
   - Configure RHCOS asset storage
   - Set up operator catalog support
   - Configure monitoring
   - Generate documentation

## Prerequisites

Ensure you have:
1. Completed the [Getting Started Guide](../getting-started/getting-started.md) prerequisites
2. SSH key at `~/.ssh/id_rsa.pub`
3. Network '1924' configured in libvirt
4. Environment variables set:
   ```bash
   HARBOR_HOSTNAME=harbor.example.com
   HARBOR_ADMIN_PASSWORD="your-secure-password"
   REGISTRY_CERTIFICATE_PATH=/path/to/certs
   ```

## Deployment Process

1. Run the deployment script:
   ```bash
   ./scripts/deploy-harbor-vm.sh
   ```

2. Monitor the deployment:
   - Script will show progress of VM creation
   - Ansible playbook execution will be verbose (-vvv)
   - Final success message will confirm completion

## Verification

After deployment completes:

1. Check Harbor UI access:
   ```bash
   echo "Access Harbor at: https://${HARBOR_HOSTNAME}"
   ```

2. Verify container registry:
   ```bash
   # Test registry login
   podman login ${HARBOR_HOSTNAME}
   
   # Test pulling an image
   podman pull ubi8/ubi-minimal
   podman tag ubi8/ubi-minimal ${HARBOR_HOSTNAME}/library/ubi-minimal
   podman push ${HARBOR_HOSTNAME}/library/ubi-minimal
   ```

## Troubleshooting

1. **VM Creation Issues**:
   ```bash
   # Check VM status
   sudo kcli list vm
   
   # View VM logs
   sudo kcli console harbor
   ```

2. **Ansible Issues**:
   ```bash
   # Check Ansible logs
   sudo journalctl -u ansible
   
   # Rerun playbook manually
   sudo ansible-playbook -i playbooks/harbor/inventory playbooks/harbor/install-harbor.yml -vvv
   ```

3. **Harbor Issues**:
   ```bash
   # Check Harbor services
   ssh ubuntu@${HARBOR_IP} 'docker-compose ps'
   
   # View Harbor logs
   ssh ubuntu@${HARBOR_IP} 'docker-compose logs'
   ```

## Next Steps

- Configure [Pull-through Cache](./pullthrough-proxy-cache-harbor.md)
- Set up [Registry Monitoring](../../reference/monitoring/harbor-monitoring.md)
- Review [Development Workflow](../../environment/development-workflow.md)

## Manual Installation

If you need to install Harbor manually (not recommended), see our [Manual Harbor Installation Guide](../../reference/alternative-implementations/manual-harbor-install.md).