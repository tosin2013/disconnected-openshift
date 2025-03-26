#!/bin/bash
set -euo pipefail
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x
#set -e


# Harbor VM configuration
HARBOR_IP="192.168.49.10"
HARBOR_MEMORY="16384"
HARBOR_CPUS="4"
HARBOR_DISK="500"
DNS_SERVER="192.168.122.22"  # FreeIPA server IP

# Check if SSH key exists
if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
    echo "SSH public key not found at $HOME/.ssh/id_rsa.pub"
    echo "Please generate an SSH key pair using: ssh-keygen -t rsa"
    exit 1
fi

# Check if network exists
if ! sudo virsh net-list | grep -q "1924"; then
    echo "Network '1924' not found. Please ensure the network is created and active."
    exit 1
fi

# Create Harbor VM
echo "Creating Harbor VM..."
sudo kcli create vm -i ubuntu2204 \
    -P nets=['{"name":"1924","ip":"'$HARBOR_IP'","netmask":"24","gateway":"192.168.49.1","dns":"'$DNS_SERVER'"}'] \
    -P memory=$HARBOR_MEMORY \
    -P cpus=$HARBOR_CPUS \
    -P disks=[$HARBOR_DISK] \
    -P keys=["$HOME/.ssh/id_rsa.pub"] \
    -P cmds=['echo "nameserver '$DNS_SERVER'" > /etc/resolv.conf'] \
    harbor

# Wait for VM to be ready
echo "Waiting for VM to be ready..."
sleep 60

# Test connectivity with timeout
echo "Testing connectivity..."
TIMEOUT=300  # 5 minutes timeout
START_TIME=$(date +%s)

while true; do
    if ping -c 1 -W 1 $HARBOR_IP >/dev/null 2>&1; then
        echo "Successfully connected to $HARBOR_IP"
        break
    fi

    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        echo "Timeout waiting for VM to become reachable"
        exit 1
    fi

    echo "Waiting for VM to become reachable... ($ELAPSED_TIME seconds elapsed)"
    sleep 5
done

# Test SSH connectivity
echo "Testing SSH connectivity..."
TIMEOUT=300  # 5 minutes timeout
START_TIME=$(date +%s)

while true; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$HARBOR_IP 'echo "SSH connection successful"' >/dev/null 2>&1; then
        echo "Successfully established SSH connection"
        break
    fi

    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        echo "Timeout waiting for SSH to become available"
        exit 1
    fi

    echo "Waiting for SSH to become available... ($ELAPSED_TIME seconds elapsed)"
    sleep 5
done

# Run Ansible playbook
echo "Running Ansible playbook..."
sudo -E ansible-playbook -i playbooks/harbor/inventory playbooks/harbor/install-harbor.yml -vvv

echo "Harbor deployment complete!" 