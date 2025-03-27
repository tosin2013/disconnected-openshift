# Disconnected OpenShift - A Compendium

> This repo is a work in progress as we gather various different sources into this one place and make our scripts more robust and maintainable.

## What This Solves

Deploying OpenShift in disconnected, semi-connected, and barely-connected environments requires managing multiple components:

- OpenShift binaries and CLI tools
- Container images for OpenShift releases
- RHCOS (Red Hat CoreOS) media
- Operators and their dependencies
- OpenShift Update Service and Graph Data
- And more...

For a detailed understanding of the architecture and design decisions, see our:
- [Architecture Overview](docs/architecture/overview.md)
- [Architecture Decision Records](docs/adr/0000-index.md)

This repository simplifies these challenges by providing:

✅ **Proxy Support**
- Complete outbound HTTP proxy configuration
- SSL MitM handling with custom Root CA helpers
- Transparent proxy cache setup guides

✅ **Registry Management**
- Private registry configuration and deployment
- Multi-architecture support (including FIPS)
- Pull-through cache setup for Harbor and JFrog

✅ **Automation Options**
- Azure DevOps Pipelines
- GitHub Actions workflows
- Ansible Automation/Execution Environments
- Tekton Pipelines

✅ **Enterprise Features**
- RHACM policy examples for disconnected configs
- Integration guides for ACM, DevSpaces, OpenShift AI
- Quay and virtualization setup in disconnected mode

## Prerequisites

### Required Components
- **Pull Secrets**
  ```bash
  # Combine registry pull secrets
  ./scripts/join-auths.sh registry1-auth.json registry2-auth.json
  ```

- **Container Registry**
  - Support for Harbor, JFrog, Nexus, or Quay
  - Examples for each registry included
  - Pull-through cache configuration guides

- **HTTP Server** (Optional but recommended)
  - Example deployments included
  - Used for serving RHCOS and other assets

- **Linux Server**
  - RHEL 9 recommended (other distros supported)
  - Physical, virtual, or even a laptop
  - Minimum specs in [system requirements](docs/requirements.md)

## Quick Start

### 1. Mirror Essential Components
```bash
# 1. Get OpenShift binaries
./binaries/mirror-binaries.sh

# 2. Mirror release images
./openshift-release/mirror-release.sh

# 3. Download RHCOS assets
./rhcos/download-rhcos.sh
```

### 2. Deploy Infrastructure
```bash
# 1. Deploy your registry (example using Harbor)
./scripts/deploy-harbor-vm.sh

# 2. Configure authentication
./scripts/pull-secret-to-harbor-auth.sh
./scripts/join-auths.sh

# 3. Start HTTP server (if needed)
./scripts/start-http-server.sh
```

### 3. Install OpenShift
Follow our [installation examples](./installation-examples/) for your scenario:
- Fully disconnected
- Semi-connected (limited internet)
- Proxy-based setups

## Documentation Structure

### Core Setup
1. [Download/Mirror OpenShift Binaries](./binaries/) - [ADR-0006](docs/adr/0006-binary-management-strategy.md)
2. [Mirror OpenShift Release Images](./openshift-release/) - [ADR-0002](docs/adr/0002-registry-management-strategy.md)
3. [Obtain RHCOS Assets](./rhcos/) - [ADR-0006](docs/adr/0006-binary-management-strategy.md)
4. [Deploy OpenShift - Disconnected Examples](./installation-examples/) - [ADR-0009](docs/adr/0009-openshift-agent-installation.md)
5. [Post-Install Configuration](./post-install-config/) - [ADR-0005](docs/adr/0005-gitops-implementation.md)

### Advanced Topics
6. [Operator Mirroring Guide](./docs/operator-mirroring.md)
7. [Update Graph Container Creation](./docs/update-graph.md)
8. [Custom CatalogSource Setup](./docs/catalogsources.md)
9. [OpenShift Update Service](./docs/update-service.md)
10. [Automation Examples](./docs/automation.md) - [ADR-0003](docs/adr/0003-pipeline-automation-approach.md)

## Additional Resources

### Quick References
- [Extras](./extras/) - Helper scripts and quick deployment examples
- [Tekton Resources](./tekton/) - Disconnected build and mirror pipelines
- [Ansible EDA + Tekton](./docs/deploy-aap-on-openshift.md) - Automated image mirroring

### Registry Guides
- [Dev/Test Quay on OpenShift](./quay/)
- [Harbor on Podman](./docs/deploy-harbor-podman-compose.md)
- [Harbor Pull-through Cache](./docs/pullthrough-proxy-cache-harbor.md)
- [JFrog Pull-through Cache](./docs/pullthrough-proxy-cache-jfrog.md)

## The Easier Way: Pull-Through Cache

Instead of manually mirroring everything, consider using your existing artifact repository as a pull-through cache:

1. **Configure Proxy Repositories**
   ```bash
   # Example mappings:
   quay.io -> quay-ptc.registry.example.com
   registry.redhat.io -> redhat-ptc.registry.example.com
   ```

2. **Update Pull Secrets**
   ```bash
   # Combine Red Hat and private registry secrets
   ./scripts/join-auths.sh redhat-pull-secret.json private-registry-secret.json
   ```

3. **Configure OpenShift**
   - Add registry certificates/CAs
   - Set up image mirror configuration
   - Deploy and you're done!

### Caveats
- Update Graph data still needs manual handling for fully disconnected setups
- Some components need additional configuration:
  - Root CA management
  - OpenShift Virtualization mirror settings
  - Samples Operator configuration
  - Image Config CR adjustments

But this is much simpler than manually mirroring everything!

## Contributing

- Fork the repository
- Create a feature branch
- Submit a pull request
- Check our [contribution guidelines](CONTRIBUTING.md)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
