# Setting Up OpenShift Pipelines for Image Mirroring in Disconnected Environments

## Introduction

This guide details how to set up and configure OpenShift Pipelines (Tekton) to automate mirroring container images from a source registry to a local Harbor registry within a disconnected OpenShift environment. The solution provides a reusable pipeline template that handles authentication, TLS verification, and proper image copying using Skopeo.

### Target Audience

This guide assumes:
- Basic <base64-credentials>
- Basic <base64-credentials>
- Familiarity with command-line operations
- Basic <base64-credentials>

### Repository Structure

This document assumes you are working from the root of the `disconnected-openshift` repository, which contains:
```
disconnected-openshift/
├── tekton/
│   ├── tasks/              # Reusable Tekton tasks
│   ├── pipelines/          # Pipeline definitions
│   └── pipeline-runs/      # Example pipeline runs
├── docs/                   # Documentation
└── scripts/               # Helper scripts
```

All commands and paths in this guide are relative to the repository root.

## Prerequisites

### Required Tools
- `oc` CLI (OpenShift Command Line Interface)
- `tkn` CLI (Tekton Command Line Interface) - [Installation Guide](https://<your-domain>
- `jq` (JSON processor) - Required for auth configuration
- `podman` or `docker` - For local registry interactions

### Required Access
- Cluster-admin access for operator installation
- Project admin access for pipeline setup
- Harbor registry access with project creation rights

### Environment Requirements
1. OpenShift cluster (4.x+) with:
   - Access to Operator Hub or disconnected operator catalog
   - Sufficient compute resources for pipeline execution
2. Harbor registry:
   - Accessible from OpenShift cluster nodes
   - TLS certificates properly configured
   - Admin credentials available
3. Network Requirements:
   - Access to source registry (e.g., registry.redhat.io) or intermediate mirror
   - Proper proxy configuration if using proxied environment

### Important Note About Placeholders

Throughout this document, you'll see placeholders that you must replace with your environment-specific values:
- `<your-harbor-fqdn>` - Your Harbor registry's fully qualified domain name
- `<your-harbor-project>` - The Harbor project name for mirrored images
- `<your-harbor-admin-password>` - Your Harbor admin password
- `<your-project-namespace>` - The OpenShift namespace for pipeline deployment

Example:
```yaml
# Template
destination_url: "docker://<your-harbor-fqdn>/<your-harbor-project>/ubi-minimal:latest"

# Actual Usage
destination_url: "docker://harbor.example.com/mirror/ubi-minimal:latest"
```

## Architecture Overview

Before diving into the setup, let's understand the key components and their interactions:

1. **OpenShift Pipelines Operator**
   - Provides Tekton infrastructure
   - Installs core tasks and controllers

2. **Skopeo Task**
   - Handles image copying between registries
   - Manages authentication and TLS verification

3. **Workspaces**
   - `authsecret`: Contains registry credentials
   - `root-ca-certs`: TLS certificates for secure registry communication
   - `registriesd`: Registry configuration for Skopeo
   - `containerconfig`: Container runtime configuration

4. **Authentication**
   - Combined secret containing both:
     - Source registry credentials (e.g., registry.redhat.io)
     - Destination registry credentials (Harbor)

5. **Harbor Integration**
   - Dedicated project for mirrored images
   - TLS certificates for secure communication
   - Robot accounts or admin credentials for authentication

The following sections will guide you through setting up each component.

## Pipeline Configuration

### 1. Example Pipeline Runs Location
The repository contains example pipeline runs in:
- `tekton/pipeline-runs/skopeo-copy-disconnected/05_plr-skopeo-copy-disconnected-single.yml`
- `tekton/pipeline-runs/openshift-release/` (for OpenShift release images)
- `tekton/pipeline-runs/binaries/` (for binary artifacts)

### 2. Configurable Variables

The main variables you'll need to modify are in the pipeline run files. Here's an example structure:

```
"Authorization: Basic <base64-credentials>
```


```yaml
# Location: tekton/pipeline-runs/skopeo-copy-disconnected/05_plr-skopeo-copy-disconnected-single.yml
spec:
  params:
    # Source and destination images
    - name: SOURCE_IMAGE_URL
      value: "docker://registry.redhat.io/ubi8/ubi-minimal:latest"  # Change this to your source image
    - name: DESTINATION_IMAGE_URL
      value: "docker://harbor.f2775.sandbox999.opentlc.com/mirror/ubi-minimal:latest"    # Using Harbor FQDN

    # Optional proxy configuration
    - name: HTTP_PROXY
      value: ""    # Add your HTTP proxy if needed
    - name: HTTPS_PROXY
      value: ""    # Add your HTTPS proxy if needed
    - name: NO_PROXY
      value: ""    # Add no_proxy exceptions if needed

    # TLS verification settings
    - name: SRC_TLS_VERIFY
      value: "true"    # For registry.redhat.io
    - name: DEST_TLS_VERIFY
      value: "true"    # For Harbor

  workspaces:
    # Authentication configuration
    - name: authsecret
      secret:
        secretName: harbor-auth    # Must match the secret name you created

    # Optional registry configuration
    - name: registriesd           # For registry mirror configuration
      configMap:
        name: mirror-registry-config
        items:
          - key: "<your-key>"
            path: mirror.conf

    # Optional container configuration
    - name: containerconfig       # For container runtime configuration
      configMap:
        name: mirror-registry-config
        items:
          - key: "<your-key>"
            path: registries.conf

    # Optional CA certificates
    - name: root-ca-certs        # For custom CA certificates
      configMap:
        items:
          - key: "<your-key>"
            path: ca-bundle.crt
        name: root-ca-certs
```

### 3. Configuration Files

1. **Registry Authentication** (`~/.docker/config.json`):
   - Location: `/home/lab-user/.docker/config.json`
   - Contains registry credentials
   - Used to create the `harbor-auth` secret

2. **Registry Configuration**:
   Create a ConfigMap for registry configuration:
   ```bash
   # Create registry configuration
   cat <<EOF > registries.conf
   [[registry]]
   location = "harbor.f2775.sandbox999.opentlc.com"
   insecure = false
   EOF

   # Create ConfigMap
   oc create configmap mirror-registry-config \
     --from-file=registries.conf=registries.conf \
     -n harbor-pipelines
   ```

3. **CA Certificates**:
   Using existing Let's Encrypt certificates:
   ```bash
   # Create CA bundle ConfigMap using existing certificates
   oc create configmap root-ca-certs \
     --from-file=ca-bundle.crt=/etc/letsencrypt/live/harbor.f2775.sandbox999.opentlc.com/fullchain.pem \
     -n harbor-pipelines
   ```

### 4. Example PipelineRun

Here's a complete example for mirroring an image:

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: mirror-test-
  namespace: harbor-pipelines
spec:
  pipelineRef:
    name: skopeo-copy-disconnected-single
  params:
    - name: SOURCE_IMAGE_URL
      value: "docker://registry.redhat.io/ubi8/ubi-minimal:latest"
    - name: DESTINATION_IMAGE_URL
      value: "docker://harbor.f2775.sandbox999.opentlc.com/mirror/ubi-minimal:latest"
    - name: SRC_TLS_VERIFY
      value: "true"
    - name: DEST_TLS_VERIFY
      value: "true"
    - name: ARGS
      value: "--all"
  workspaces:
    - name: authsecret
      secret:
        secretName: combined-registry-auth    # Using the combined credentials secret
    - name: root-ca-certs
      configMap:
        name: root-ca-certs
    - name: registriesd
      configMap:
        name: mirror-registry-config
```

## Installation Steps

### 1. Install OpenShift Pipelines Operator

```bash
# Create the openshift-pipelines-operator namespace
oc create -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-pipelines-operator
EOF

# Create the operator group
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-pipelines-operator
spec:
  targetNamespaces:
  - openshift-pipelines-operator
EOF

# Create the subscription
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-pipelines-operator
spec:
  channel: latest
  name: openshift-pipelines-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

Verify the operator installation:
```bash
oc get csv -n openshift-pipelines-operator
```

### 2. Create Pipeline Project

Create a dedicated project for running our pipelines:
```bash
# Create project
oc new-project <your-project-namespace>  # Example: harbor-pipelines
```

### 3. Harbor Project Setup

Before configuring the pipeline, ensure you have a project in Harbor for mirrored images:

```bash
# Create the mirror project in Harbor
# Note: Replace <your-harbor-fqdn> and <your-harbor-admin-password> with your values
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <base64-credentials>
  "https://<your-domain> \
  -d '{
    "project_name": "mirror",
    "metadata": {
      "public": "false",
      "auto_scan": "true",
      "reuse_sys_cve_allowlist": "true"
    }
  }'

# Expected Response:
# - HTTP 201: Project created successfully
# - HTTP 409: Project already exists (safe to ignore)
```

## Configuration Steps

### 1. Authentication Setup

Create a combined registry credentials secret that includes both Red Hat and Harbor authentication:

```bash
# 1. Get the Red Hat pull secret
oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > redhat-pull-secret.json

# 2. Create Harbor credentials
# For Podman users:
podman login <your-harbor-fqdn>
cp ${XDG_RUNTIME_DIR}/containers/auth.json harbor-auth.json

# For Docker users:
docker login <your-harbor-fqdn>
cp ~/.docker/config.json harbor-auth.json

# 3. Merge the credentials
# Combines Red Hat registry auth with Harbor auth into a single secret
jq -s '.[0].auths * .[1].auths | {auths: .}' \
  redhat-pull-secret.json harbor-auth.json > combined-auth.json

# 4. Create the secret in OpenShift
oc create secret generic combined-registry-auth \
  --from-file=.dockerconfigjson=combined-auth.json \
  --type=kubernetes.io/dockerconfigjson \
  -n <your-project-namespace>

# 5. Link the secret to the pipeline service account
oc secrets link pipeline combined-registry-auth \
  --for=pull,mount -n <your-project-namespace>

# 6. Clean up temporary files
rm redhat-pull-secret.json harbor-auth.json combined-auth.json
```

### 2. TLS Certificate Configuration

Create a ConfigMap containing the Harbor CA certificate:

```bash
# If using Let's Encrypt certificates
oc create configmap root-ca-certs \
  --from-file=ca-bundle.crt=/etc/letsencrypt/live/<your-harbor-fqdn>/chain.pem \
  -n <your-project-namespace>

# Alternative: If you have the certificate from another source
# 1. Save your CA certificate as ca-bundle.crt
# 2. Create the ConfigMap:
oc create configmap root-ca-certs \
  --from-file=ca-bundle.crt=./ca-bundle.crt \
  -n <your-project-namespace>
```

### 3. Registry Configuration

Create a ConfigMap for Skopeo's registry configuration:

```bash
# Create the registries.conf content
cat > registries.conf <<EOF
[[registry]]
location = "<your-harbor-fqdn>"
insecure = false
EOF

# Create the ConfigMap
oc create configmap mirror-registry-config \
  --from-file=registries.conf \
  -n <your-project-namespace>
```

This configuration:
- Tells Skopeo how to connect to your Harbor registry
- Enforces TLS verification (insecure = false)
- Will be mounted in both registriesd and containerconfig workspaces for proper container runtime configuration

### 4. Apply Tekton Resources

Apply the provided Tekton task and pipeline definitions:

```bash
# Apply the skopeo copy task
oc apply -f tekton/tasks/skopeo-copy-disconnected.yml

# Apply the pipeline
oc apply -f tekton/pipelines/skopeo-copy-disconnected-single.yml
```

## Usage

### Pipeline Parameters

The pipeline accepts the following parameters:

- `SOURCE_IMAGE_URL`: Source image URL (e.g., "docker://registry.redhat.io/ubi8/ubi-minimal:latest")
- `DESTINATION_IMAGE_URL`: Destination image URL in your Harbor registry
- `SRC_TLS_VERIFY`: Enable/disable TLS verification for source registry (default: "true")
- `DEST_TLS_VERIFY`: Enable/disable TLS verification for destination registry (default: "true")
- `ARGS`: Additional arguments for skopeo copy (default: "--all" to copy all tags)
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`: Proxy settings if required

### Running the Pipeline

Create a PipelineRun to mirror an image:

```bash
# Replace placeholders in the example PipelineRun
sed -i \
  -e "s/harbor.f2775.sandbox999.opentlc.com/<your-harbor-fqdn>/g" \
  tekton/pipeline-runs/skopeo-copy-disconnected/05_plr-skopeo-copy-disconnected-single.yml

# Create the PipelineRun
oc create -f tekton/pipeline-runs/skopeo-copy-disconnected/05_plr-skopeo-copy-disconnected-single.yml
```

### Monitoring Pipeline Execution

Monitor the pipeline run:
```bash
# Watch the pipeline run status
tkn pipelinerun list
tkn pipelinerun logs -f -l tekton.dev/pipeline=skopeo-copy-disconnected-single

# Check for successful image mirror
podman pull <your-harbor-fqdn>/mirror/ubi-minimal:latest
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   ```
   error: authentication required
   ```
   - Verify the combined-registry-auth secret contains valid credentials
   - Check the secret is properly linked to the pipeline service account
   - Ensure credentials haven't expired

2. **TLS/Certificate Issues**
   ```
   x509: certificate signed by unknown authority
   ```
   - Verify the root-ca-certs ConfigMap contains the correct CA certificate
   - Check the certificate chain is complete
   - Ensure the certificate hasn't expired

3. **Image Pull/Push Failures**
   ```
   manifest unknown: manifest unknown
   ```
   - Verify the image exists in the source registry
   - Check you have pull permissions for the source image
   - Ensure you have push permissions to the destination project

4. **Signature Verification Issues**
   ```
   Source image rejected: A signature was required, but no signature exists
   ```
   - If using Red Hat images, ensure you have the Red Hat public key
   - Consider disabling signature verification if appropriate
   - Configure policy.json if signature verification is required

### Debugging Steps

1. **Check Pipeline Run Status**
   ```bash
   tkn pipelinerun describe <pipelinerun-name>
   ```

2. **View Detailed Logs**
   ```bash
   tkn pipelinerun logs <pipelinerun-name> -f
   ```

3. **Inspect Task Pod**
   ```bash
   # Get the pod name
   oc get pods -l tekton.dev/pipelineTask=skopeo-copy-disconnected
   
   # Get pod details
   oc describe pod <pod-name>
   
   # Get pod logs
   oc logs <pod-name> -c step-copy
   ```

4. **Verify Workspace Mounts**
   ```bash
   # Check pod's mounted volumes
   oc describe pod <pod-name> | grep -A 10 Volumes
   ```

5. **Test Registry Access**
   ```bash
   # Test Harbor connectivity
   curl -k https://<your-harbor-fqdn>/v2/
   
   # Test authentication
   podman login <your-harbor-fqdn>
   ```

## Maintenance

### Cleanup

1. **Remove Old Pipeline Runs**
   ```bash
   # Keep the 5 most recent runs, delete others
   tkn pipelinerun delete --keep 5
   ```

2. **Update Credentials**
   ```bash
   # Update the combined registry auth secret
   oc create secret generic combined-registry-auth \
     --from-file=.dockerconfigjson=new-combined-auth.json \
     --type=kubernetes.io/dockerconfigjson \
     -n <your-project-namespace> \
     --dry-run=client -o yaml | oc replace -f -
   ```

3. **Update CA Certificates**
   ```bash
   # Update the root CA certificates
   oc create configmap root-ca-certs \
     --from-file=ca-bundle.crt=new-ca-bundle.crt \
     -n <your-project-namespace> \
     --dry-run=client -o yaml | oc replace -f -
   ```

### Monitoring

1. **Pipeline Health**
   ```bash
   # Check pipeline run success rate
   tkn pipelinerun list --limit 10
   ```

2. **Resource Usage**
   ```bash
   # Check pod resource usage
   oc adm top pods -l tekton.dev/pipeline=skopeo-copy-disconnected-single
   ```

3. **Harbor Storage**
   ```bash
   # Monitor Harbor project quotas
   curl -k -H "Authorization: Basic <base64-credentials>
     https://<your-domain>
   ```

## Advanced Configuration

### Custom Pipeline Parameters

You can customize the pipeline run with additional parameters:

```yaml
spec:
  params:
    # Proxy Configuration
    - name: HTTP_PROXY
      value: "http://<your-domain>
    - name: HTTPS_PROXY
      value: "http://<your-domain>
    - name: NO_PROXY
      value: ".local,.cluster.local,<ip-address>/8"
    
    # Skopeo Arguments
    - name: ARGS
      value: "--all --preserve-digests --src-tls-verify=false"
```

### Multiple Registry Support

To mirror images between multiple registries:

1. Add additional registry credentials to the combined-registry-auth secret
2. Update the registries.conf ConfigMap with additional registry entries
3. Create separate pipeline runs for each source/destination pair

### Automated Cleanup

Create a CronJob to clean up old pipeline runs:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pipelinerun-cleanup
  namespace: <your-project-namespace>
spec:
  schedule: "0 0 * * *"  # Run daily at midnight
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: pipeline
          containers:
          - name: tkn
            image: registry.redhat.io/openshift-pipelines/pipelines-cli:latest
            command:
            - /usr/bin/tkn
            - pipelinerun
            - delete
            - --keep
            - "5"
            - --force
          restartPolicy: OnFailure
```

## Reference

### File Locations

- Pipeline Definitions: `tekton/pipelines/`
- Task Definitions: `tekton/tasks/`
- Example Pipeline Runs: `tekton/pipeline-runs/`
- Helper Scripts: `scripts/`

### Important Commands

```bash
# Create pipeline run
tkn pipeline start skopeo-copy-disconnected-single \
  -p SOURCE_IMAGE_URL="docker://registry.redhat.io/ubi8/ubi-minimal:latest" \
  -p DESTINATION_IMAGE_URL="docker://<your-harbor-fqdn>/mirror/ubi-minimal:latest"

# Monitor pipeline
tkn pipelinerun logs -f -l tekton.dev/pipeline=skopeo-copy-disconnected-single

# Clean up
tkn pipelinerun delete --keep 5
```

### Related Documentation

- [OpenShift Pipelines Documentation](https://<your-domain>
- [Harbor Documentation](https://<your-domain>
- [Skopeo Documentation](https://<your-domain>
- [Container Image Signing](https://<your-domain>

---
Last Updated: March 26, 2024 
