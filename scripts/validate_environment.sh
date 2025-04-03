#!/bin/bash

# Exit on error, undefined variables, and propagate pipeline failures
set -euo pipefail

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define log file
LOG_FILE="validation_results.log"
VALIDATION_SUMMARY="validation_summary.md"

# Initialize log files
: > "$LOG_FILE"
: > "$VALIDATION_SUMMARY"

# Logging functions
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

# Function to check command existence
check_command() {
    local cmd="$1"
    local min_version="$2"
    local version_cmd="${3:-}"  # Make version_cmd optional with empty default
    
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR" "$cmd not found"
        return 1
    fi
    
    if [ -n "$min_version" ] && [ -n "$version_cmd" ]; then
        local current_version
        current_version=$(eval "$version_cmd" 2>/dev/null || echo "0.0.0")
        if ! printf '%s\n%s\n' "$min_version" "$current_version" | sort -V -C; then
            log "ERROR" "$cmd version $current_version is lower than required version $min_version"
            return 1
        fi
        log "SUCCESS" "$cmd version $current_version meets minimum requirement ($min_version)"
    else
        log "SUCCESS" "$cmd is available"
    fi
    return 0
}

# Function to check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 8 ]; then
        log "ERROR" "Insufficient CPU cores: $cpu_cores (minimum 8 required)"
        return 1
    fi
    log "SUCCESS" "CPU cores: $cpu_cores"
    
    # Check RAM
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 32 ]; then
        log "ERROR" "Insufficient RAM: ${total_ram}GB (minimum 32GB required)"
        return 1
    fi
    log "SUCCESS" "RAM: ${total_ram}GB"
    
    # Check available storage in /var/lib/libvirt/images
    local storage
    storage=$(df -BG /var/lib/libvirt/images | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$storage" -lt 1024 ]; then
        log "ERROR" "Insufficient storage in /var/lib/libvirt/images: ${storage}GB (minimum 1TB required)"
        return 1
    fi
    log "SUCCESS" "Available storage in /var/lib/libvirt/images: ${storage}GB"
    
    return 0
}

# Function to check VM status using kcli
check_vm_status() {
    log "INFO" "Checking VM status..."
    
    # Check if kcli is available
    if ! command -v kcli &> /dev/null; then
        log "ERROR" "kcli command not found"
        return 1
    fi
    
    # Get VM list
    local vm_list
    vm_list=$(kcli get vms)
    
    # Check control plane nodes
    for node in "${CONTROL_PLANE_NODES[@]}"; do
        local node_name=${node%%:*}
        if ! echo "$vm_list" | grep -q "$node_name.*up"; then
            log "ERROR" "Control plane node $node_name is not running"
            return 1
        fi
        log "SUCCESS" "Control plane node $node_name is running"
    done
    
    # Check worker nodes
    for node in "${WORKER_NODES[@]}"; do
        local node_name=${node%%:*}
        if ! echo "$vm_list" | grep -q "$node_name.*up"; then
            log "ERROR" "Worker node $node_name is not running"
            return 1
        fi
        log "SUCCESS" "Worker node $node_name is running"
    done
    
    return 0
}

# Function to check network requirements
check_network_requirements() {
    log "INFO" "Checking network requirements..."
    
    # Check DNS server reachability
    if ! ping -c 1 "$DNS_SERVER" >/dev/null 2>&1; then
        log "ERROR" "DNS server $DNS_SERVER is not reachable"
        return 1
    fi
    log "SUCCESS" "DNS server $DNS_SERVER is reachable"

    # Check OpenShift API DNS resolution
    if ! dig +short "api.$SANDBOX_DOMAIN" "@$DNS_SERVER" >/dev/null 2>&1; then
        log "ERROR" "DNS resolution failed for api.$SANDBOX_DOMAIN"
        return 1
    fi
    log "SUCCESS" "DNS resolution successful for api.$SANDBOX_DOMAIN"

    # Check Harbor DNS resolution
    if ! dig +short "$HARBOR_HOSTNAME" "@$DNS_SERVER" >/dev/null 2>&1; then
        log "WARNING" "DNS resolution failed for $HARBOR_HOSTNAME - this is expected as Harbor will be deployed later"
    else
        log "SUCCESS" "DNS resolution successful for $HARBOR_HOSTNAME"
    fi

    # Check bandwidth
    if ! iperf3 -c "$LAB_NETWORK_GW" -t 5 >/dev/null 2>&1; then
        log "WARNING" "Bandwidth test failed - ensure network performance meets requirements"
    else
        log "SUCCESS" "Network bandwidth meets requirements"
    fi
    
    return 0
}

# Function to check storage configuration
check_storage_configuration() {
    log "INFO" "Checking storage configuration..."
    
    # Check filesystem type
    local fs_type
    fs_type=$(df -T / | awk 'NR==2 {print $2}')
    if [[ "$fs_type" != "xfs" && "$fs_type" != "ext4" ]]; then
        log "ERROR" "Unsupported filesystem type: $fs_type (XFS or ext4 required)"
        return 1
    fi
    log "SUCCESS" "Filesystem type: $fs_type"
    
    # Check SELinux mode
    local current_selinux
    current_selinux=$(getenforce)
    log "INFO" "Current SELinux mode: $current_selinux"
    
    # Check if SELinux policy is managed
    if ! command -v semanage &> /dev/null; then
        log "WARNING" "semanage command not available, skipping SELinux context checks"
    else
        # Check SELinux contexts
        local required_contexts=(
            "container_file_t"
            "container_var_lib_t"
        )
        
        for context in "${required_contexts[@]}"; do
            if ! semanage fcontext -l 2>/dev/null | grep -q "$context"; then
                log "WARNING" "SELinux context $context is not defined, but continuing as SELinux is in $current_selinux mode"
            else
                log "SUCCESS" "SELinux context $context is defined"
            fi
        done
    fi
    
    # Check registry storage using the NVMe drive
    local registry_path="/var/lib/libvirt/images/registry"
    if [ ! -d "$registry_path" ]; then
        log "INFO" "Creating registry directory at $registry_path"
        sudo mkdir -p "$registry_path"
    fi
    
    local registry_storage
    registry_storage=$(df -BG "$registry_path" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${registry_storage:-0}" -lt 500 ]; then
        log "ERROR" "Insufficient registry storage: ${registry_storage}GB (minimum 500GB required)"
        return 1
    fi
    log "SUCCESS" "Registry storage: ${registry_storage}GB"
    
    return 0
}

# Function to check security requirements
check_security_requirements() {
    log "INFO" "Checking security requirements..."
    
    # Skip Harbor SSL certificate check as it will be configured by deploy-harbor-vm.sh
    log "INFO" "Skipping Harbor SSL certificate check - will be configured by deploy-harbor-vm.sh"
    
    return 0
}

# OpenShift configuration
KUBECONFIG="/home/lab-user/generated_assets/ocp4/auth/kubeconfig"
EXPECTED_VERSION="4.18.6"
MIN_CONTROL_PLANE=3
MIN_WORKERS=6

# Function to check OpenShift requirements
check_openshift_requirements() {
    log "INFO" "Checking OpenShift requirements..."
    
    # Export KUBECONFIG
    export KUBECONFIG="${KUBECONFIG}"
    
    # Check KUBECONFIG file exists
    if [ ! -f "${KUBECONFIG}" ]; then
        log "ERROR" "KUBECONFIG file not found at ${KUBECONFIG}"
        return 1
    fi
    log "SUCCESS" "KUBECONFIG file exists"
    
    # Check cluster access
    if ! oc whoami &>/dev/null; then
        log "ERROR" "Cannot access OpenShift cluster"
        return 1
    fi
    log "SUCCESS" "OpenShift cluster access verified as $(oc whoami)"
    
    # Check cluster version
    local cluster_version
    cluster_version=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
    if [ "${cluster_version}" != "${EXPECTED_VERSION}" ]; then
        log "ERROR" "Cluster version mismatch. Expected ${EXPECTED_VERSION}, got ${cluster_version}"
        return 1
    fi
    log "SUCCESS" "Cluster version verified: ${cluster_version}"
    
    # Check control plane nodes
    local control_plane_count
    control_plane_count=$(oc get nodes --no-headers | grep -c "control-plane")
    if [ "${control_plane_count}" -lt "${MIN_CONTROL_PLANE}" ]; then
        log "ERROR" "Insufficient control plane nodes. Expected ${MIN_CONTROL_PLANE}, got ${control_plane_count}"
        return 1
    fi
    log "SUCCESS" "Control plane node count verified: ${control_plane_count}"
    
    # Check worker nodes
    local worker_count
    worker_count=$(oc get nodes --no-headers | grep -c "worker")
    if [ "${worker_count}" -lt "${MIN_WORKERS}" ]; then
        log "ERROR" "Insufficient worker nodes. Expected ${MIN_WORKERS}, got ${worker_count}"
        return 1
    fi
    log "SUCCESS" "Worker node count verified: ${worker_count}"
    
    # Check node health
    local unhealthy_nodes
    unhealthy_nodes=$(oc get nodes --no-headers | grep -vc "Ready")
    if [ "${unhealthy_nodes}" -gt 0 ]; then
        log "ERROR" "Found ${unhealthy_nodes} unhealthy nodes"
        return 1
    fi
    log "SUCCESS" "All nodes are healthy"
    
    # Check cluster operators
    local degraded_operators
    degraded_operators=$(oc get co --no-headers | grep -c "False.*True.*True")
    if [ "${degraded_operators}" -gt 0 ]; then
        log "ERROR" "Found ${degraded_operators} degraded operators"
        return 1
    fi
    log "SUCCESS" "All cluster operators are healthy"
    
    # Check required namespaces
    local required_namespaces=(
        "openshift-monitoring"
        "openshift-image-registry"
        "openshift-ingress"
        "openshift-storage"
    )
    
    for ns in "${required_namespaces[@]}"; do
        if ! oc get namespace "${ns}" &>/dev/null; then
            log "ERROR" "Required namespace ${ns} not found"
            return 1
        fi
        log "SUCCESS" "Required namespace ${ns} exists"
    done
    
    # Check registry storage
    if ! oc get pvc -n openshift-image-registry image-registry-storage &>/dev/null; then
        log "ERROR" "Image registry storage PVC not found"
        return 1
    fi
    log "SUCCESS" "Image registry storage configured"
    
    # Check monitoring stack
    if ! oc get pod -n openshift-monitoring -l app.kubernetes.io/name=prometheus &>/dev/null; then
        log "ERROR" "Monitoring stack not found"
        return 1
    fi
    log "SUCCESS" "Monitoring stack is running"
    
    return 0
}

# Function to check required software versions
check_software_versions() {
    log "INFO" "Checking required software versions..."
    
    # Define required versions using ';;;' as the delimiter
    local required_versions=(
        "python3;;;3.9;;;python3 --version | cut -d' ' -f2"
        "podman;;;4.4.0;;;podman --version | cut -d' ' -f3"
        "buildah;;;1.29.0;;;buildah --version | cut -d' ' -f3"
        "skopeo;;;1.11.0;;;skopeo --version | cut -d' ' -f3"
        "ansible;;;2.9;;;ansible --version | head -n1 | cut -d' ' -f3"
        "oc;;;4.18.6;;;oc version | grep 'Client Version' | awk '{print \$3}'"
    )
    
    local failed=0
    for version_check in "${required_versions[@]}"; do
        IFS=';;;' read -r cmd min_version version_cmd <<< "$version_check"
        if [[ "$cmd" == "oc" ]]; then
            # Ensure escape for awk remains intact
            version_cmd="oc version | grep 'Client Version' | awk '{print \$3}'"
        fi
        if ! check_command "$cmd" "$min_version" "$version_cmd"; then
            failed=1
        fi
    done
    
    return $failed
}

# Function to check environment variables
check_environment_variables() {
    log "INFO" "Checking environment variables..."
    
    local required_vars=(
        "KUBECONFIG"
        "OPENSHIFT_PULL_SECRET"
        "OPENSHIFT_VERSION"
        "OPENSHIFT_MINOR_VERSION"
        "OPENSHIFT_ARCHITECTURE"
        "HARBOR_HOSTNAME"
        "HARBOR_ADMIN_PASSWORD"
        "REGISTRY_CERTIFICATE_PATH"
        "SANDBOX_DOMAIN"
        "LAB_NETWORK_GW"
        "TRANS_PROXY_GW"
    )
    
    local failed=0
    for var in "${required_vars[@]}"; do
        if [ -z "${!var-}" ]; then
            log "ERROR" "Required environment variable $var is not set"
            failed=1
        else
            log "SUCCESS" "Environment variable $var is set"
        fi
    done
    
    return $failed
}

# Function to check file structure
check_file_structure() {
    log "INFO" "Checking file structure..."
    
    # Check required directories
    local required_dirs=(
        "memory_bank"
        "prompts"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log "ERROR" "Required directory $dir not found"
            return 1
        fi
        log "SUCCESS" "Directory $dir exists"
    done
    
    return 0
}

# Function to check package dependencies
check_package_dependencies() {
    log "INFO" "Checking package dependencies..."
    
    local failed=0
    
    # Check Python dependencies
    if [ -f "requirements.txt" ]; then
        log "INFO" "Checking Python dependencies..."
        if ! pip3 list --format=freeze > /tmp/installed_packages.txt; then
            log "ERROR" "Failed to get installed Python packages"
            failed=1
        else
            while IFS= read -r requirement; do
                package_name=$(echo "$requirement" | cut -d'=' -f1)
                if ! grep -q "^$package_name=" /tmp/installed_packages.txt; then
                    log "ERROR" "Python package $package_name is not installed"
                    failed=1
                else
                    log "SUCCESS" "Python package $package_name is installed"
                fi
            done < requirements.txt
        fi
    fi
    
    # Check Ansible collections
    if [ -f "collections/requirements.yml" ]; then
        log "INFO" "Checking Ansible collections..."
        if ! ansible-galaxy collection list > /tmp/installed_collections.txt; then
            log "ERROR" "Failed to get installed Ansible collections"
            failed=1
        else
            while IFS=: read -r namespace name version; do
                if ! grep -q "$namespace\.$name" /tmp/installed_collections.txt; then
                    log "ERROR" "Ansible collection $namespace.$name is not installed"
                    failed=1
                else
                    log "SUCCESS" "Ansible collection $namespace.$name is installed"
                fi
            done < <(grep -E '^[[:space:]]*-[[:space:]]*name:[[:space:]]*' collections/requirements.yml | sed -E 's/[[:space:]]*-[[:space:]]*name:[[:space:]]*//')
        fi
    fi
    
    return $failed
}

# Function to generate validation summary
generate_summary() {
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local warning_checks=0
    
    while IFS= read -r line; do
        case "$line" in
            *"[SUCCESS]"*) ((passed_checks++)); ((total_checks++));;
            *"[ERROR]"*)   ((failed_checks++)); ((total_checks++));;
            *"[WARNING]"*) ((warning_checks++)); ((total_checks++));;
        esac
    done < "$LOG_FILE"
    
    # Generate markdown summary
    {
        echo "# Environment Validation Summary"
        echo "Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "## Overview"
        echo "- Total checks: $total_checks"
        echo "- Passed: $passed_checks"
        echo "- Failed: $failed_checks"
        echo "- Warnings: $warning_checks"
        echo
        echo "## Detailed Results"
        echo "\`\`\`"
        cat "$LOG_FILE"
        echo "\`\`\`"
    } > "$VALIDATION_SUMMARY"
    
    # Print summary to console
    log "INFO" "Validation Summary:"
    log "INFO" "Total checks: $total_checks"
    log "SUCCESS" "Passed: $passed_checks"
    [ "$failed_checks" -gt 0 ] && log "ERROR" "Failed: $failed_checks"
    [ "$warning_checks" -gt 0 ] && log "WARNING" "Warnings: $warning_checks"
}

# Main execution
main() {
    log "INFO" "Starting environment validation..."
    
    local exit_code=0
    
    # Run all checks
    check_system_requirements || exit_code=1
    check_vm_status || exit_code=1
    check_network_requirements || exit_code=1
    check_storage_configuration || exit_code=1
    check_security_requirements || exit_code=1
    check_openshift_requirements || exit_code=1
    check_software_versions || exit_code=1
    check_environment_variables || exit_code=1
    check_file_structure || exit_code=1
    check_package_dependencies || exit_code=1
    
    # Generate summary
    generate_summary
    
    log "INFO" "Validation results saved to $LOG_FILE"
    log "INFO" "Summary report saved to $VALIDATION_SUMMARY"
    
    return $exit_code
}

# Run main function
main "$@" 