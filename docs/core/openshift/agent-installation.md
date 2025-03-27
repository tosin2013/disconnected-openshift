# OpenShift Agent-Based Installation

This guide covers the agent-based installation of OpenShift 4.18 in a disconnected environment, following the implementation defined in [ADR-0009](../../adr/0009-openshift-agent-installation.md).

## Prerequisites

1. **System Requirements**
   - A RHEL system to work from
   - OpenShift CLI Tools
   - NMState CLI (`dnf install nmstate`)
   - Ansible Core (`dnf install ansible-core`)
   - Ansible Collections for automation
   - Red Hat OpenShift Pull Secret from [console.redhat.com](https://console.redhat.com/openshift/downloads#tool-pull-secret)
   - Any additional pull secrets for disconnected registry

2. **Required Tools Installation**
   ```bash
   # Download and install OpenShift CLI tools
   ./download-openshift-cli.sh
   sudo cp ./bin/* /usr/local/bin/

   # Install Ansible collections
   ansible-galaxy install -r playbooks/collections/requirements.yml

   # Verify installations
   oc version
   nmstatectl --version
   ansible --version
   ```

3. **Configuration Files**
   ```bash
   # Clone the agent installer repository
   git clone https://github.com/Red-Hat-SE-RTO/openshift-agent-install.git
   cd openshift-agent-install
   ```

## Installation Process

1. **Prepare Installation Environment**

   Create your cluster configuration in a dedicated folder with `cluster.yml` and `nodes.yml`:

   ```bash
   # Example cluster.yml
   pull_secret_path: ~/ocp-install-pull-secret.json
   base_domain: example.com
   cluster_name: my-cluster
   platform_type: none  # baremetal, vsphere, or none

   # VIPs configuration
   api_vips:
   - 192.168.70.46
   app_vips:
   - 192.168.70.46

   # Network configuration
   cluster_network_cidr: 10.128.0.0/14
   cluster_network_host_prefix: 23
   service_network_cidrs:
   - 172.30.0.0/16
   machine_network_cidrs:
   - 192.168.70.0/23
   network_type: OVNKubernetes

   # Disconnected Registry configuration
   disconnected_registries:
     # Must have direct references to openshift-release-dev paths
     - target: disconn-harbor.example.com/quay-ptc/openshift-release-dev/ocp-release
       source: quay.io/openshift-release-dev/ocp-release
     - target: disconn-harbor.example.com/quay-ptc/openshift-release-dev/ocp-v4.0-art-dev
       source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
     # General registry mirrors
     - target: disconn-harbor.example.com/quay-ptc
       source: quay.io
     - target: disconn-harbor.example.com/registry-redhat-io-ptc
       source: registry.redhat.io
     - target: disconn-harbor.example.com/registry-connect-redhat-com-ptc
       source: registry.connect.redhat.com

   # Optional: Additional trust bundle for your registry
   additional_trust_bundle_policy: Always
   additional_trust_bundle: |
     -----BEGIN CERTIFICATE-----
     Your registry's CA certificate here
     -----END CERTIFICATE-----

   # Optional: Proxy configuration if needed
   proxy:
     http_proxy: http://proxy.example.com:3128
     https_proxy: http://proxy.example.com:3128
     no_proxy:
       - .svc.cluster.local
       - 192.168.0.0/16
       - .example.com
   ```

2. **Node Configuration**

   Create a `nodes.yml` file for your cluster:

   ```yaml
   # Node configuration
   control_plane_replicas: 3
   app_node_replicas: 2

   nodes:
   - hostname: master1
     role: master
     rootDeviceHints:
       deviceName: /dev/nvme0n1
     interfaces:
     - name: eno1
       mac_address: 00:50:56:B3:EA:71
       networkConfig:
         interfaces:
         - name: eno1
           type: ethernet
           state: up
           ipv4:
             enabled: true
             address:
             - ip: 192.168.70.46
               prefix-length: 23
             dhcp: false
   ```

3. **Generate Installation Media**
   ```bash
   # Generate the ISO using the provided script
   ./hack/create-iso.sh my-cluster
   ```

4. **Start Installation**
   ```bash
   # Monitor the bootstrap process
   openshift-install agent wait-for bootstrap-complete --dir ./generated_manifests/

   # Watch the installation complete
   openshift-install agent wait-for install-complete --dir ./generated_manifests/
   ```

## Network Configuration Examples

### VLAN Configuration
```yaml
networkConfig:
  interfaces:
    - name: eno1.70
      type: vlan
      state: up
      vlan:
        id: 70
        base-iface: eno1
      ipv4:
        enabled: true
        address:
          - ip: 192.168.70.46
            prefix-length: 23
        dhcp: false
```

### Bond Configuration
```yaml
networkConfig:
  interfaces:
    - name: bond0
      type: bond
      state: up
      ipv4:
        address:
          - ip: 192.168.70.46
            prefix-length: 23
        dhcp: false
        enabled: true
      link-aggregation:
        mode: 802.3ad  # mode=4 802.3ad
        port:
          - eno1
          - eno2
```

## Post-Installation

1. **Verify Cluster Status**
   ```bash
   # Check cluster operators
   oc get co
   
   # Verify nodes
   oc get nodes
   
   # Check cluster version
   oc get clusterversion
   ```

2. **Configure Authentication**
   ```bash
   # Set up htpasswd authentication
   oc create secret generic htpass-secret \
     --from-file=htpasswd=/path/to/htpasswd \
     -n openshift-config
   
   # Apply OAuth configuration
   oc apply -f oauth-config.yaml
   ```

3. **Setup Registry**
   ```bash
   # Configure internal registry
   oc patch configs.imageregistry.operator.openshift.io cluster \
     --type merge \
     --patch '{"spec":{"managementState":"Managed"}}'
   
   # Configure storage
   oc patch configs.imageregistry.operator.openshift.io cluster \
     --type merge \
     --patch '{"spec":{"storage":{"pvc":{"claim":""}}}}'
   ```

## Troubleshooting

### Common Issues

1. **Node Boot Failures**
   ```bash
   # Check node status
   oc get nodes
   
   # View node logs
   oc adm node-logs <node-name>
   ```

2. **Operator Issues**
   ```bash
   # Check operator status
   oc get co
   
   # View operator logs
   oc logs -n openshift-cluster-version \
     deployment/cluster-version-operator
   ```

3. **Network Problems**
   ```bash
   # Verify network operator
   oc get network.operator cluster -o yaml
   
   # Check SDN pods
   oc get pods -n openshift-sdn
   ```

### Recovery Steps

1. **Bootstrap Recovery**
   ```bash
   # Gather bootstrap logs
   openshift-install agent gather bootstrap
   
   # Review logs
   less bootstrap/log-bundle-*.tar.gz
   ```

2. **Node Recovery**
   ```bash
   # Approve pending CSRs
   oc get csr
   oc adm certificate approve <csr-name>
   ```

## Next Steps

1. Configure [Registry Integration](registry-config.md)
2. Set up [Security Components](security/README.md)
3. Implement [Monitoring](monitoring/README.md)

## References

- [OpenShift Agent Install Repository](https://github.com/Red-Hat-SE-RTO/openshift-agent-install)
- [OpenShift 4.18 Documentation](https://docs.openshift.com/container-platform/4.18/) 