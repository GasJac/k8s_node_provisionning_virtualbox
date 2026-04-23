#!/bin/bash

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_DIR="$REPO_DIR/tools/.ssh"
TERRAFORM_DIR="$REPO_DIR/terraform"
ANSIBLE_DIR="$REPO_DIR/ansible"

echo -e "\e[36m"
echo "  ██╗  ██╗ █████╗ ███████╗    ██╗   ██╗██████╗  ██████╗ ██╗  ██╗"
echo "  ██║ ██╔╝██╔══██╗██╔════╝    ██║   ██║██╔══██╗██╔═══██╗╚██╗██╔╝"
echo "  █████╔╝ ╚█████╔╝███████╗    ██║   ██║██████╔╝██║   ██║ ╚███╔╝ "
echo "  ██╔═██╗ ██╔══██╗╚════██║    ╚██╗ ██╔╝██╔══██╗██║   ██║ ██╔██╗ "
echo "  ██║  ██╗╚█████╔╝███████║     ╚████╔╝ ██████╔╝╚██████╔╝██╔╝ ██╗"
echo "  ╚═╝  ╚═╝ ╚════╝ ╚══════╝      ╚═══╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
echo -e "\e[0m"
echo -e "\e[35m  ┌─────────────────────────────────────────────────────┐"
echo    "  │        K8s VBox — Kubernetes node provider          │"
echo    "  │        Terraform + Ansible + VirtualBox             │"
echo -e "  └─────────────────────────────────────────────────────┘\e[0m"
echo ""

# Input
read -p "Please enter the IP address of your K8s master : " MASTER_IP
read -p "Please enter the User of your K8s master : " MASTER_USER
read -s -p "Please enter the Password of your K8s master : " MASTER_PASS
echo ""

# SSH dir
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# ── Terraform ────────────────────────────────────────────────────────
cd "$TERRAFORM_DIR"
bash terraform_apply.sh
if [ $? -ne 0 ]; then
  echo -e "\e[31mTerraform failed, aborting.\e[0m"
  exit 1
fi

WORKER_IP=$(python3 -c "
import json
with open('terraform.tfstate') as f:
    state = json.load(f)
for r in state.get('resources', []):
    for i in r.get('instances', []):
        adapters = i.get('attributes', {}).get('network_adapter', [])
        if adapters:
            print(adapters[0].get('ipv4_address', ''))
            exit()
")

if [ -z "$WORKER_IP" ]; then
  echo -e "\e[31mCould not retrieve worker IP from tfstate, aborting.\e[0m"
  exit 1
fi

echo -e "\e[35mEnd of terraform provisioning — Worker IP: $WORKER_IP\e[0m"

# ── SSH keys ─────────────────────────────────────────────────────────
echo -e "\e[35mGenerating key pair\e[0m"
ssh-add -D 2>/dev/null
rm -f "$SSH_DIR/id_rsa" "$SSH_DIR/id_rsa.pub"
ssh-keygen -t rsa -f "$SSH_DIR/id_rsa" -q -N ""

ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$WORKER_IP" 2>/dev/null
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$MASTER_IP" 2>/dev/null

echo "Waiting for worker SSH to be ready..."
for i in $(seq 1 24); do
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      -i "$SSH_DIR/id_rsa" vagrant@$WORKER_IP exit 2>/dev/null && break
  echo "  Attempt $i/24, retrying in 10s..."
  sleep 10
done

sshpass -p "vagrant" ssh-copy-id \
  -o StrictHostKeyChecking=no -o IdentitiesOnly=yes \
  -i "$SSH_DIR/id_rsa.pub" vagrant@$WORKER_IP

sshpass -p "$MASTER_PASS" ssh-copy-id \
  -o StrictHostKeyChecking=no -o IdentitiesOnly=yes \
  -i "$SSH_DIR/id_rsa.pub" $MASTER_USER@$MASTER_IP

# ── Ansible ──────────────────────────────────────────────────────────
cd "$ANSIBLE_DIR"

cp inventaire.ini.backup inventaire.ini
sed -i "s|WORKER_IP_PLACEHOLDER|${WORKER_IP}|g"     inventaire.ini
sed -i "s|MASTER_IP_PLACEHOLDER|${MASTER_IP}|g"     inventaire.ini
sed -i "s|MASTER_USER_PLACEHOLDER|${MASTER_USER}|g" inventaire.ini

echo -e "\e[35mRunning playbook.yml\e[0m"
ansible-playbook playbook.yml -i inventaire.ini \
  --extra-vars "ansible_sudo_pass=${MASTER_PASS}"
if [ $? -ne 0 ]; then
  echo -e "\e[31mplaybook.yml failed, aborting.\e[0m"
  exit 1
fi

echo -e "\e[35mRunning join-cluster\e[0m"
ansible-playbook roles/join-cluster/main.yml -i inventaire.ini \
  --extra-vars "ansible_sudo_pass=${MASTER_PASS}"
if [ $? -ne 0 ]; then
  echo -e "\e[31mjoin-cluster failed.\e[0m"
  exit 1
fi

echo -e "\e[32m"
echo "  ✔  Worker $WORKER_IP successfully joined the cluster!"
echo -e "\e[0m"
