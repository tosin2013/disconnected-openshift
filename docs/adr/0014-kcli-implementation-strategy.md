# ADR-0014: Kcli Implementation Strategy

## Status

Accepted

## Context

The project requires a robust VM and cluster management solution that supports:
- OpenShift agent-based installation
- Disconnected environment deployment
- Multiple VM management
- Network configuration
- Infrastructure automation

## Decision

We will implement kcli (v99.0) as the primary VM and cluster management tool with the following components:

1. **Infrastructure Management**
   - **VM Deployment**
     - Control plane nodes (3)
     - Worker nodes (6)
     - Infrastructure services (FreeIPA, VyOS Router)
     - Resource allocation and monitoring
   
   - **Network Configuration**
     - Worker subnet (<ip-address>/24)
     - Infrastructure subnet (<ip-address>/24)
     - Network isolation
     - DNS management

2. **OpenShift Integration**
   - **Cluster Deployment**
     - Agent-based installation
     - Disconnected registry support
     - Custom machine configurations
     - Automated deployment workflows
   
   - **Infrastructure Services**
     - FreeIPA for authentication
     - VyOS for routing
     - Registry services integration
     - Monitoring integration

3. **Automation Framework**
   - **Deployment Automation**
     - VM provisioning
     - Network configuration
     - Service deployment
     - Configuration management
   
   - **Integration Points**
     - Registry services
     - GitOps workflows
     - Monitoring systems
     - Security services

4. **Operational Support**
   - **Maintenance**
     - VM lifecycle management
     - Cluster updates
     - Service updates
     - Configuration updates
   
   - **Monitoring**
     - Resource utilization
     - Service health
     - Network status
     - Performance metrics

## Consequences

### Positive
- Unified management interface
- Automated deployment capabilities
- Consistent environment setup
- Integrated monitoring
- Simplified maintenance

### Negative
- Learning curve for kcli
- Additional tool dependencies
- Configuration complexity
- Resource overhead

## Alternatives Considered

1. **Manual VM Management**
   - Pros: Direct control, simpler setup
   - Cons: Error-prone, not scalable

2. **Cloud-based Solutions**
   - Pros: Managed service, scalability
   - Cons: Not suitable for disconnected environments

3. **Custom Automation Scripts**
   - Pros: Tailored to specific needs
   - Cons: Maintenance overhead, limited features

## Implementation Notes

- Follow kcli best practices
- Document deployment procedures
- Establish backup procedures
- Regular maintenance schedule
- Version control for configurations

## References

- [Kcli Documentation](https://<your-domain>
- [OpenShift Agent Installation](https://<your-domain>
- [Disconnected Installation](https://<your-domain>
- [Kcli OpenShift Integration](https://<your-domain> 