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
SCRIPT_NAME="deploy-harbor-vm.sh"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="Deploy Harbor registry on a VM for disconnected OpenShift environment"

# Logging setup
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/harbor_vm_deploy_$(date +%Y%m%d_%H%M%S).log"
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
    echo "  --vm-name <name>     Name of the Harbor VM"
    echo "  --vm-memory <size>   VM memory size in GB (default: 16)"
    echo "  --vm-cpus <count>    Number of CPU cores (default: 4)"
    echo "  --vm-disk <size>     VM disk size in GB (default: 100)"
    echo "  --network <name>     Network name for VM (default: default)"
    echo "  --help              Show this help message"
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

# Function to check VM requirements
check_vm_requirements() {
    log "INFO" "Checking VM requirements..."
    
    # Check if VM name is provided
    if [ -z "${VM_NAME:-}" ]; then
        log "ERROR" "VM name not provided"
        return 1
    fi
    
    # Check if VM already exists
    if virsh list --all | grep -q "$VM_NAME"; then
        log "ERROR" "VM $VM_NAME already exists"
        return 1
    fi
    
    # Check available resources
    local available_memory
    available_memory=$(free -g | awk '/^Mem:/{print $7}')
    if [ "$available_memory" -lt "${VM_MEMORY:-16}" ]; then
        log "ERROR" "Insufficient memory: ${available_memory}GB available, ${VM_MEMORY:-16}GB required"
        return 1
    fi
    
    local available_cpus
    available_cpus=$(nproc)
    if [ "$available_cpus" -lt "${VM_CPUS:-4}" ]; then
        log "ERROR" "Insufficient CPU cores: $available_cpus available, ${VM_CPUS:-4} required"
        return 1
    fi
    
    local available_disk
    available_disk=$(df -BG /var/lib/libvirt/images | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt "${VM_DISK:-100}" ]; then
        log "ERROR" "Insufficient disk space: ${available_disk}GB available, ${VM_DISK:-100}GB required"
        return 1
    fi
    
    log "SUCCESS" "VM requirements check passed"
    return 0
}

# Function to create Harbor VM
create_harbor_vm() {
    log "INFO" "Creating Harbor VM..."
    
    # Create VM disk
    local disk_path="/var/lib/libvirt/images/${VM_NAME}.qcow2"
    qemu-img create -f qcow2 "$disk_path" "${VM_DISK:-100}G"
    
    # Create cloud-init ISO
    local cloud_init_dir="/tmp/cloud-init"
    mkdir -p "$cloud_init_dir"
    
    # Generate cloud-init config
    cat > "$cloud_init_dir/user-data" << EOF
#cloud-config
hostname: ${VM_NAME}
manage_etc_hosts: true
users:
  - name: harbor
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
EOF
    
    # Generate network config
    cat > "$cloud_init_dir/network-config" << EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
    match:
      macaddress: \${MAC_ADDRESS}
EOF
    
    # Create cloud-init ISO
    cloud-localds "$cloud_init_dir/seed.img" "$cloud_init_dir/user-data" "$cloud_init_dir/network-config"
    
    # Create and start VM
    virt-install \
        --name "$VM_NAME" \
        --memory "${VM_MEMORY:-16}" \
        --vcpus "${VM_CPUS:-4}" \
        --disk "$disk_path" \
        --disk "$cloud_init_dir/seed.img,device=cdrom" \
        --network network="${NETWORK:-default}" \
        --graphics none \
        --console pty,target_type=serial \
        --os-variant rhel8.5 \
        --wait -1
    
    log "SUCCESS" "Harbor VM created successfully"
    return 0
}

# Function to configure Harbor VM
configure_harbor_vm() {
    log "INFO" "Configuring Harbor VM..."
    
    # Wait for VM to be accessible
    log "INFO" "Waiting for VM to be accessible..."
    until ssh -o StrictHostKeyChecking=no harbor@${VM_NAME} "echo 'VM is ready'"; do
        sleep 5
    done
    
    # Install required packages
    ssh harbor@${VM_NAME} << 'EOF'
        sudo dnf update -y
        sudo dnf install -y podman buildah skopeo docker-compose
        sudo systemctl enable --now podman.socket
        sudo usermod -aG docker harbor
EOF
    
    # Configure Harbor
    ssh harbor@${VM_NAME} << EOF
        mkdir -p ~/harbor
        cd ~/harbor
        
        # Download Harbor installer
        curl -LO https://github.com/goharbor/harbor/releases/download/v2.8.0/harbor-offline-installer-v2.8.0.tgz
        tar xzf harbor-offline-installer-v2.8.0.tgz
        
        # Configure Harbor
        cat > harbor.yml << 'YAML'
hostname: ${HARBOR_HOSTNAME}
http:
  port: 80
https:
  port: 443
  certificate: /etc/pki/ca-trust/source/anchors/harbor.crt
  private_key: /etc/pki/ca-trust/source/anchors/harbor.key
harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}
database:
  password: ${HARBOR_DB_PASSWORD}
core:
  secret: ${HARBOR_CORE_SECRET}
jobservice:
  secret: ${HARBOR_JOBSERVICE_SECRET}
registry:
  secret: ${HARBOR_REGISTRY_SECRET}
YAML
        
        # Install Harbor
        sudo ./install.sh
        
        # Configure systemd service
        sudo tee /etc/systemd/system/harbor.service << 'SERVICE'
[Unit]
Description=Harbor Container Registry
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/harbor
ExecStart=/usr/local/bin/docker-compose -f /opt/harbor/docker-compose.yml up -d
ExecStop=/usr/local/bin/docker-compose -f /opt/harbor/docker-compose.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE
        
        sudo systemctl daemon-reload
        sudo systemctl enable harbor
        sudo systemctl start harbor
EOF
    
    log "SUCCESS" "Harbor VM configured successfully"
    return 0
}

# Function to verify Harbor deployment
verify_harbor_deployment() {
    log "INFO" "Verifying Harbor deployment..."
    
    # Check Harbor service status
    if ! ssh harbor@${VM_NAME} "sudo systemctl is-active --quiet harbor"; then
        log "ERROR" "Harbor service is not running"
        return 1
    fi
    
    # Check Harbor web interface
    if ! curl -k -s "https://${HARBOR_HOSTNAME}" > /dev/null; then
        log "ERROR" "Harbor web interface is not accessible"
        return 1
    fi
    
    # Test Harbor login
    if ! curl -k -s -u "admin:${HARBOR_ADMIN_PASSWORD}" "https://${HARBOR_HOSTNAME}/api/v2.0/users" > /dev/null; then
        log "ERROR" "Failed to authenticate with Harbor"
        return 1
    fi
    
    log "SUCCESS" "Harbor deployment verified successfully"
    return 0
}

# Main execution
main() {
    log "INFO" "Starting Harbor VM deployment process..."
    
    # Parse command line arguments
    local VM_NAME=""
    local VM_MEMORY=16
    local VM_CPUS=4
    local VM_DISK=100
    local NETWORK="default"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            --vm-memory)
                VM_MEMORY="$2"
                shift 2
                ;;
            --vm-cpus)
                VM_CPUS="$2"
                shift 2
                ;;
            --vm-disk)
                VM_DISK="$2"
                shift 2
                ;;
            --network)
                NETWORK="$2"
                shift 2
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
    
    # Check VM requirements
    if ! check_vm_requirements; then
        log "ERROR" "VM requirements check failed"
        exit 1
    fi
    
    # Create Harbor VM
    if ! create_harbor_vm; then
        log "ERROR" "Failed to create Harbor VM"
        exit 1
    fi
    
    # Configure Harbor VM
    if ! configure_harbor_vm; then
        log "ERROR" "Failed to configure Harbor VM"
        exit 1
    fi
    
    # Verify Harbor deployment
    if ! verify_harbor_deployment; then
        log "ERROR" "Harbor deployment verification failed"
        exit 1
    fi
    
    log "SUCCESS" "Harbor VM deployment completed successfully"
    log "INFO" "Deployment log saved to: $LOG_FILE"
    
    return 0
}

# Run main function
main "$@" 