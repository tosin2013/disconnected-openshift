#!/bin/bash

# Exit on error, undefined variables, and propagate pipeline failures
set -euo pipefail

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script metadata
SCRIPT_NAME="build_environment.sh"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="Build and configure environment for disconnected OpenShift deployment"

# OpenShift configuration
KUBECONFIG="/home/lab-user/generated_assets/ocp4/auth/kubeconfig"
EXPECTED_VERSION="4.18.6"
MIN_NODES=9  # 3 control plane + 6 workers

# Logging setup
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/build_environment_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Initialize log file
: > "$LOG_FILE"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")   echo -e "${RED}✗ ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✓ ${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}! ${message}${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ ${message}${NC}" ;;
    esac
}

# Help function
show_help() {
    echo "Usage: $SCRIPT_NAME [OPTIONS]"
    echo
    echo "Options:"
    echo "  --interactive    Run in interactive mode (default)"
    echo "  --non-interactive Run in non-interactive mode using environment variables"
    echo "  --verbose       Enable verbose output"
    echo "  --help          Show this help message"
    echo
    echo "Description:"
    echo "  $SCRIPT_DESCRIPTION"
    echo
    echo "Version: $SCRIPT_VERSION"
}

# Signal handling
cleanup() {
    log "INFO" "Cleaning up..."
    # Add cleanup tasks here
    exit 0
}

trap cleanup SIGINT SIGTERM

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "ERROR" "Required command '$1' not found"
        return 1
    fi
    return 0
}

# Function to install required packages
install_packages() {
    log "INFO" "Installing required packages..."
    
    # Check if running on RHEL/CentOS
    if [ -f /etc/redhat-release ]; then
        # Install container tools
        log "INFO" "Installing container tools..."
        sudo dnf module enable -y container-tools
        sudo dnf install -y podman buildah skopeo
        
        # Install other required packages
        sudo dnf install -y ansible git python3-pip python3-devel
        
        # Install OpenShift CLI
        if ! command -v oc &> /dev/null; then
            log "INFO" "Installing OpenShift CLI..."
            curl -LO "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz"
            sudo tar xzf openshift-client-linux.tar.gz -C /usr/local/bin/
            rm openshift-client-linux.tar.gz
        fi
    else
        log "ERROR" "Unsupported operating system"
        return 1
    fi
    
    return 0
}

# Function to configure SELinux
configure_selinux() {
    log "INFO" "Configuring SELinux..."
    
    # Check if SELinux is installed
    if ! command -v semanage &> /dev/null; then
        log "ERROR" "SELinux management tools not found"
        return 1
    fi
    
    # Set SELinux to enforcing mode
    if [ "$(getenforce)" != "Enforcing" ]; then
        log "INFO" "Setting SELinux to Enforcing mode..."
        sudo setenforce 1
        sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    fi
    
    # Configure required SELinux contexts
    local contexts=(
        "container_file_t"
        "container_var_lib_t"
    )
    
    for context in "${contexts[@]}"; do
        if ! semanage fcontext -l | grep -q "$context"; then
            log "INFO" "Adding SELinux context: $context"
            sudo semanage fcontext -a -t "$context" "/var/lib/containers(/.*)?"
        fi
    done
    
    return 0
}

# Function to configure firewall
configure_firewall() {
    log "INFO" "Configuring firewall..."
    
    local required_ports=(
        "443/tcp"
        "6443/tcp"
        "22623/tcp"
        "2379-2380/tcp"
        "10250/tcp"
        "10257/tcp"
        "10259/tcp"
    )
    
    for port in "${required_ports[@]}"; do
        if ! firewall-cmd --list-ports | grep -q "$port"; then
            log "INFO" "Opening port: $port"
            sudo firewall-cmd --permanent --add-port="$port"
        fi
    done
    
    sudo firewall-cmd --reload
    return 0
}

# Function to configure DNS
configure_dns() {
    log "INFO" "Configuring DNS..."
    
    # Add DNS entries to /etc/hosts if needed
    if ! grep -q "${HARBOR_HOSTNAME}" /etc/hosts; then
        log "INFO" "Adding Harbor hostname to /etc/hosts..."
        echo "127.0.0.1 ${HARBOR_HOSTNAME}" | sudo tee -a /etc/hosts
    fi
    
    return 0
}

# Function to generate SSL certificates
generate_certificates() {
    log "INFO" "Generating SSL certificates..."
    
    local cert_dir="/etc/pki/ca-trust/source/anchors"
    sudo mkdir -p "$cert_dir"
    
    # Generate self-signed certificate for Harbor
    if [ ! -f "${cert_dir}/harbor.crt" ]; then
        log "INFO" "Generating Harbor SSL certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${cert_dir}/harbor.key" \
            -out "${cert_dir}/harbor.crt" \
            -subj "/CN=${HARBOR_HOSTNAME}"
        
        # Update CA trust
        sudo update-ca-trust
    fi
    
    return 0
}

# Function to create required directories
create_directories() {
    log "INFO" "Creating required directories..."
    
    local required_dirs=(
        "cli/commands"
        "templates"
        "analysis"
        "memory_bank"
        "prompts"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log "INFO" "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    return 0
}

# Function to create requirements.txt
create_requirements() {
    log "INFO" "Creating requirements.txt..."
    
    cat > requirements.txt << 'EOF'
# Core dependencies
kubernetes>=28.1.0
openshift>=0.13.2
pyyaml>=6.0.1
jinja2>=3.1.2
requests>=2.31.0
urllib3>=2.1.0
cryptography>=41.0.7
python-dateutil>=2.8.2
six>=1.16.0
certifi>=2023.11.17
charset-normalizer>=3.3.2
idna>=3.6
EOF
    
    return 0
}

# Function to install Python dependencies
install_python_deps() {
    log "INFO" "Installing Python dependencies..."
    
    if [ -f "requirements.txt" ]; then
        pip3 install --ignore-installed -r requirements.txt
    fi
    
    return 0
}

# Function to check OpenShift cluster access
check_openshift_access() {
    log "INFO" "Checking OpenShift cluster access..."
    
    # Export KUBECONFIG
    export KUBECONFIG="${KUBECONFIG}"
    
    # Check if we can connect to the cluster
    if ! oc whoami &>/dev/null; then
        log "ERROR" "Cannot connect to OpenShift cluster. Check KUBECONFIG path: ${KUBECONFIG}"
        return 1
    fi
    log "SUCCESS" "Successfully connected to OpenShift cluster as $(oc whoami)"
    
    # Check cluster version
    local cluster_version
    cluster_version=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
    if [ "${cluster_version}" != "${EXPECTED_VERSION}" ]; then
        log "ERROR" "Cluster version mismatch. Expected ${EXPECTED_VERSION}, got ${cluster_version}"
        return 1
    fi
    log "SUCCESS" "Cluster version verified: ${cluster_version}"
    
    # Check node count and status
    local ready_nodes
    ready_nodes=$(oc get nodes --no-headers | grep -c "Ready")
    if [ "${ready_nodes}" -lt "${MIN_NODES}" ]; then
        log "ERROR" "Insufficient ready nodes. Expected ${MIN_NODES}, got ${ready_nodes}"
        return 1
    fi
    log "SUCCESS" "Node count verified: ${ready_nodes} nodes ready"
    
    # Check cluster operators
    local degraded_operators
    degraded_operators=$(oc get co --no-headers | grep -c "False.*True.*True")
    if [ "${degraded_operators}" -gt 0 ]; then
        log "ERROR" "Found ${degraded_operators} degraded operators"
        return 1
    fi
    log "SUCCESS" "All cluster operators are healthy"
    
    return 0
}

# Function to configure OpenShift environment
configure_openshift() {
    log "INFO" "Configuring OpenShift environment..."
    
    # Create required namespaces
    log "INFO" "Creating required namespaces..."
    for ns in monitoring logging registry pipelines; do
        if ! oc get namespace "${ns}" &>/dev/null; then
            oc create namespace "${ns}"
            log "SUCCESS" "Created namespace: ${ns}"
        else
            log "INFO" "Namespace ${ns} already exists"
        fi
    done
    
    # Configure image registry storage
    log "INFO" "Configuring image registry storage..."
    if ! oc get pvc -n openshift-image-registry image-registry-storage &>/dev/null; then
        oc patch configs.imageregistry.operator.openshift.io cluster --type merge \
            --patch '{"spec":{"storage":{"pvc":{"claim":""}}}}'
        log "SUCCESS" "Configured image registry storage"
    fi
    
    # Configure monitoring
    log "INFO" "Configuring cluster monitoring..."
    if ! oc get configmap cluster-monitoring-config -n openshift-monitoring &>/dev/null; then
        oc create configmap cluster-monitoring-config -n openshift-monitoring \
            --from-literal=config.yaml='{"enableUserWorkload": true}'
        log "SUCCESS" "Configured cluster monitoring"
    fi
    
    return 0
}

# Main execution
main() {
    log "INFO" "Starting environment build process..."
    
    # Parse command line arguments
    local interactive=true
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive)
                interactive=false
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Run validation script first
    log "INFO" "Running environment validation..."
    if ! ./scripts/validate_environment.sh; then
        log "WARNING" "Environment validation failed. Some components may need manual configuration."
    fi
    
    # Check OpenShift access first
    if ! check_openshift_access; then
        log "ERROR" "OpenShift cluster access check failed"
        exit 1
    fi
    
    # Install required packages
    if ! install_packages; then
        log "ERROR" "Failed to install required packages"
        exit 1
    fi
    
    # Configure system components
    if ! configure_selinux; then
        log "ERROR" "Failed to configure SELinux"
        exit 1
    fi
    
    if ! configure_firewall; then
        log "ERROR" "Failed to configure firewall"
        exit 1
    fi
    
    if ! configure_dns; then
        log "ERROR" "Failed to configure DNS"
        exit 1
    fi
    
    if ! generate_certificates; then
        log "ERROR" "Failed to generate SSL certificates"
        exit 1
    fi
    
    # Create project structure
    if ! create_directories; then
        log "ERROR" "Failed to create required directories"
        exit 1
    fi
    
    # Setup Python environment
    if ! create_requirements; then
        log "ERROR" "Failed to create requirements.txt"
        exit 1
    fi
    
    if ! install_python_deps; then
        log "ERROR" "Failed to install Python dependencies"
        exit 1
    fi
    
    # Configure OpenShift environment
    if ! configure_openshift; then
        log "ERROR" "OpenShift configuration failed"
        exit 1
    fi
    
    log "SUCCESS" "Environment build completed successfully"
    log "INFO" "Build log saved to: $LOG_FILE"
    
    return 0
}

# Run main function
main "$@" 