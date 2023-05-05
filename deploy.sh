#!/bin/bash

echo "  _______________________________________________________________
      |                                                             |
      |                                                             |
      |            K8s VirtualBox Node provider                     |
      |_____________________________________________________________|" 
#retrieve k8s master IP
read -p "Please enter the Ip addresse of your K8s master : " MASTER_IP
echo $MASTER_IP;
read -p "Please enter the User of your K8s master : " USER
echo $USER;
read -s -p "Please enter the Password of your K8s master : " PASS

#create a directory to store our ssh keys
mkdir -p tools/.ssh

#terraform provisioning
cd ./terraform && bash terraform_apply.sh
IP=`cat terraform.tfstate | grep ipv4_address | head -n1 | cut -f 2 -d ':' | cut -f 2 -d ' ' |tr ',' ' '`
echo -e "\e[35mEnd of terraform provisioning"

#for the first provisionning we need to generate a key pair to access the node
echo -e "\e[35mGenerating key pair\e[35m"
rm ../tools/.ssh/id_rsa
rm ../tools/.ssh/id_rsa.pub
#retrieve the worker ip
HOST=`echo $IP | cut -d '"' -f 2`
ssh-keygen -f "/home/gas/.ssh/known_hosts" -R "${HOST}"
ssh-keygen -f "/home/gas/.ssh/known_hosts" -R "${MASTER_IP}"
ssh-keygen -t rsa -f ../tools/.ssh/id_rsa -q -P ""
sshpass -p "vagrant" ssh-copy-id -o IdentitiesOnly=yes -i ../tools/.ssh/id_rsa.pub vagrant@$HOST
#and master
sshpass -p "${PASS}" ssh-copy-id -o IdentitiesOnly=yes -i ../tools/.ssh/id_rsa.pub $USER@$MASTER_IP

#ansible deployment
cd ../ansible
#backup inventory
cp inventaire.ini inventaire.ini.backup
#replace host with IP of the VM
sed -i "s|worker_2_ip|${HOST}|g" inventaire.ini
sed -i "s|master_ip|${MASTER_IP}|g" inventaire.ini
ansible-playbook playbook.yml -i inventaire.ini --user $USER --extra-vars "ansible_sudo_pass=${PASS}"
ansible-playbook roles/join-cluster/main.yml -i inventaire.ini --user $USER --extra-vars "ansible_sudo_pass=${PASS}"
#replace inventory.ini
#mv inventaire.ini.backup inventaire.ini
