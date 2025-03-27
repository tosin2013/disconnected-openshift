# YAML Standards Guide

## Table of Contents
- [File Organization](#file-organization)
- [Metadata and Annotations](#metadata-and-annotations)
- [Resource Specifications](#resource-specifications)
- [Environment Variables](#environment-variables)
- [Security Configurations](#security-configurations)
- [Best Practices](#best-practices)

## File Organization

### File Structure
```yaml
---
# File: example-resource.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
  namespace: default
```

### Directory Structure
```
yaml/
├── base/                 # Base configurations
├── overlays/            # Environment-specific overlays
├── templates/           # Reusable templates
└── examples/            # Example configurations
```

## Metadata and Annotations

### Required Metadata
```yaml
metadata:
  name: component-name                    # Descriptive, hyphenated name
  namespace: target-namespace             # Explicit namespace
  labels:
    app.kubernetes.io/name: myapp         # Component name
    app.kubernetes.io/instance: prod      # Instance name
    app.kubernetes.io/version: "1.0.0"    # Version number
    app.kubernetes.io/component: backend  # Component type
    app.kubernetes.io/part-of: system     # System name
```

### Annotations
```yaml
metadata:
  annotations:
    description: "Purpose of this resource"
    example.com/team: "team-name"
    example.com/contact: "team@example.com"
    example.com/doc-url: "https://<your-domain>
```

## Resource Specifications

### ConfigMap Example
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  # Group related configurations
  database:
    host: "db.example.com"
    port: "5432"
  cache:
    host: "redis.example.com"
    port: "6379"
```

### Deployment Example
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: registry.example.com/web-app:1.0.0
        # Group related configurations
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
```

## Environment Variables

### Structure
```yaml
env:
  # Required environment variables
  - name: DATABASE_URL
    value: "postgresql://db:5432/mydb"
  
  # Optional environment variables with defaults
  - name: LOG_LEVEL
    value: "INFO"
  
  # Sensitive environment variables from secrets
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: api-secrets
        key: "<your-key>"
```

### ConfigMap References
```yaml
envFrom:
  - configMapRef:
      name: app-config
  - secretRef:
      name: app-secrets
```

## Security Configurations

### Pod Security Context
```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  runAsNonRoot: true
```

### Container Security Context
```yaml
containers:
  - name: secure-app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

## Best Practices

### 1. Use Comments
```yaml
# Resource purpose
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Database configuration
  DB_HOST: "localhost"  # Use localhost for development
  
  # Cache configuration
  CACHE_TTL: "3600"    # Time in seconds
```

### 2. Consistent Formatting
```yaml
# Use 2 spaces for indentation
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: web
```

### 3. Resource Limits
```yaml
# Always specify resource requests and limits
resources:
  requests:
    cpu: "100m"     # 0.1 CPU core
    memory: "128Mi" # 128 MiB memory
  limits:
    cpu: "200m"     # 0.2 CPU core
    memory: "256Mi" # 256 MiB memory
```

### 4. Health Checks
```yaml
# Include both liveness and readiness probes
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 5. Version Control
```yaml
# Use specific versions for images
image: registry.example.com/app:1.2.3  # Good
image: registry.example.com/app:latest  # Avoid

# Use semantic versioning in labels
labels:
  app.kubernetes.io/version: "1.2.3"
```

### 6. Error Handling
```yaml
# Define behavior on failure
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: app
        # Define termination grace period
        terminationGracePeriodSeconds: 30
        # Define lifecycle hooks
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
```

### 7. Multi-document Files
```yaml
---
# First document
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config

---
# Second document
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
```

## Validation

### Pre-commit Checks
1. Run YAML linting:
```bash
yamllint .
```

2. Validate Kubernetes resources:
```bash
kubectl apply --dry-run=client -f resource.yml
```

3. Use kustomize to validate overlays:
```bash
kustomize build overlays/production | kubectl apply --dry-run=client -f -
``` 