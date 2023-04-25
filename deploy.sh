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

mkdir -p tools/.ssh

#terraform provisioning
cd ./terraform && bash terraform_apply.sh
IP=`cat terraform.tfstate | grep ipv4_address | head -n1 | cut -f 2 -d ':' | cut -f 2 -d ' ' |tr ',' ' '`

#for the first provisionning we need to generate a key pair to access the node
ssh-keygen -t rsa -f ../tools/.ssh/id_rsa -q -P ""
HOST=`echo $IP | cut -d '"' -f 2`
ssh-copy-id -o IdentitiesOnly=yes -i ./tools/.ssh/id_rsa.pub vagrant@$HOST
#and master
ssh-copy-id -o IdentitiesOnly=yes -i ./tools/.ssh/id_rsa.pub $USER@$MASTER_IP


#ansible deployment
cd ../ansible
#replace host with IP of the VM
sed -i "s|worker_2_ip|${IP}|g" playbook.yml
sed -i "s|worker_2_ip|${IP}|g" inventaire.ini
ansible-playbook playbook.yml -i inventaire.ini --user vagrant --become
