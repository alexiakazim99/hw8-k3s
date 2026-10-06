#!/bin/bash
# =============================================================
# setup.sh - creates 6 Multipass VMs for a k3s cluster and
# generates an Ansible inventory. Re-usable: run it again and
# it recreates the whole cluster from scratch.
#
#   3x control-plane (server)  +  3x worker (agent)
# =============================================================
set -e

# --- settings you can change ---
SERVER_COUNT=3
AGENT_COUNT=3
CPUS=2
MEMORY=2G
DISK=10G
UBUNTU=22.04
KEY=./id_k3s          # SSH key used to reach the VMs
# --------------------------------

echo ">> 1. Creating SSH key (if missing)"
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "k3s-cluster"
fi
PUBKEY=$(cat "${KEY}.pub")

echo ">> 2. Building cloud-init with your public key"
sed "s|__SSH_PUBLIC_KEY__|${PUBKEY}|" cloud-init.yaml > cloud-init.generated.yaml

echo ">> 3. Launching VMs"
NODES=""
for i in $(seq 1 $SERVER_COUNT); do NODES="$NODES k3s-server-$i"; done
for i in $(seq 1 $AGENT_COUNT);  do NODES="$NODES k3s-agent-$i";  done

for NODE in $NODES; do
  if multipass info "$NODE" >/dev/null 2>&1; then
    echo "   $NODE already exists, skipping"
  else
    echo "   launching $NODE"
    multipass launch --name "$NODE" \
      --cpus "$CPUS" --memory "$MEMORY" --disk "$DISK" \
      --cloud-init cloud-init.generated.yaml "$UBUNTU"
  fi
done

echo ">> 4. Collecting IP addresses"
get_ip() { multipass info "$1" | awk '/IPv4/{print $2; exit}'; }

echo ">> 5. Writing inventory.ini"
SERVER1_IP=$(get_ip k3s-server-1)
TOKEN=$(openssl rand -hex 16)

{
  echo "[server_first]"
  echo "k3s-server-1 ansible_host=$(get_ip k3s-server-1)"
  echo ""
  echo "[server_rest]"
  for i in $(seq 2 $SERVER_COUNT); do
    echo "k3s-server-$i ansible_host=$(get_ip k3s-server-$i)"
  done
  echo ""
  echo "[agents]"
  for i in $(seq 1 $AGENT_COUNT); do
    echo "k3s-agent-$i ansible_host=$(get_ip k3s-agent-$i)"
  done
  echo ""
  echo "[all:vars]"
  echo "ansible_user=ubuntu"
  echo "ansible_ssh_private_key_file=${KEY}"
  echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
  echo "k3s_token=${TOKEN}"
  echo "server1_ip=${SERVER1_IP}"
} > inventory.ini

echo ""
echo ">> DONE. 6 VMs are up. Server-1 IP: ${SERVER1_IP}"
echo ">> Next: ansible-playbook -i inventory.ini playbook.yml"
