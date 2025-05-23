# Documentation Generation Guide

## Overview
This document explains how documentation is automatically generated and maintained for the disconnected OpenShift environment setup.

## Documentation Structure

### 1. Generated Documentation Location
All generated documentation is stored in the following locations:
- `/docs/generated/`: Automatically generated documentation
- `/docs/generated/playbooks/`: Playbook documentation
- `/docs/generated/inventory/`: Inventory documentation
- `/docs/generated/variables/`: Variable documentation

### 2. Documentation Types

#### 2.1 Playbook Documentation
- Task descriptions
- Variable usage
- Dependencies
- Examples

#### 2.2 Configuration Documentation
- Current settings
- Available options
- Default values
- Configuration relationships

#### 2.3 Architecture Documentation
- Component diagrams
- Network layouts
- Integration points
- Data flows

## Generation Process

### 1. Trigger Documentation Generation
```bash
# Generate all documentation
ansible-playbook playbooks/harbor/install-harbor.yml --tags generate-docs

# Generate specific documentation
ansible-playbook playbooks/harbor/install-harbor.yml --tags "generate-docs-playbooks,generate-docs-config"
```

### 2. Documentation Sources
The documentation generator pulls information from:
- Playbook comments and metadata
- Variable definitions
- Task descriptions
- README files
- Code comments

### 3. Template Processing
Documentation is generated using templates located in:
```
templates/
├── playbook-doc.j2
├── variable-doc.j2
├── inventory-doc.j2
└── architecture-doc.j2
```

## Maintaining Documentation

### 1. Documentation Standards
- Use consistent formatting
- Include examples
- Provide context
- Link related documents

### 2. Update Process
1. Make code changes
2. Update relevant comments and metadata
3. Run documentation generation
4. Review generated docs
5. Commit changes

### 3. Quality Checks
```bash
# Validate documentation
ansible-playbook playbooks/harbor/install-harbor.yml --tags validate-docs

# Check links
ansible-playbook playbooks/harbor/install-harbor.yml --tags check-doc-links
```

## Integration with Other Tools

### 1. Version Control
- Documentation is versioned with code
- Generated docs are committed
- History is maintained

### 2. CI/CD Integration
```yaml
# Documentation generation in CI pipeline
- name: Generate Documentation
  run: |
    ansible-playbook playbooks/harbor/install-harbor.yml --tags generate-docs
    
- name: Validate Documentation
  run: |
    ansible-playbook playbooks/harbor/install-harbor.yml --tags validate-docs
```

## Troubleshooting

### Common Issues
1. Missing documentation
   - Check source comments
   - Verify template syntax
   - Review generation logs

2. Inconsistent formatting
   - Validate templates
   - Check source formatting
   - Review markdown syntax

3. Broken links
   - Run link checker
   - Update references
   - Verify file paths

## Best Practices

### 1. Documentation Writing
- Use clear, concise language
- Include practical examples
- Provide context and explanations
- Cross-reference related docs

### 2. Metadata Management
- Use consistent tags
- Document dependencies
- Include version information
- Maintain change history

### 3. Review Process
- Technical accuracy review
- Formatting consistency check
- Link validation
- User perspective review

## References
- [Ansible Documentation](https://<your-domain>
- [Markdown Guide](https://<your-domain>
- [Documentation Best Practices](https://<your-domain> 