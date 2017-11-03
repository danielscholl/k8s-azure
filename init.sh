#!/usr/bin/env bash
# Copyright (c) 2017, cloudcodeit.com
#
#  Purpose: Initialize an Azure Virtual Machine for Ansible Play
#  Usage:
#    init.sh <unique> <count>


###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: init.sh <unique> <count>" 1>&2; exit 1; }

if [ -f ~/.azure/.env ]; then source ~/.azure/.env; fi
if [ -f ./.env ]; then source ./.env; fi
if [ -f ./functions.sh ]; then source ./functions.sh; fi


if [ ! -z $1 ]; then UNIQUE=$1; fi
if [ -z $UNIQUE ]; then
  tput setaf 1; echo 'ERROR: UNIQUE not found' ; tput sgr0
  usage;
fi
if [ -z ${AZURE_LOCATION} ]; then
  tput setaf 1; echo 'ERROR: Global Variable AZURE_LOCATION not set'; tput sgr0
  exit 1;
fi

if [ ! -z $2 ]; then COUNT=$2; fi
if [ -z $COUNT ]; then
  COUNT=1
fi

###############################
## Azure Intialize           ##
###############################
tput setaf 2; echo 'Logging in and setting subscription...' ; tput sgr0
az account set --subscription ${AZURE_SUBSCRIPTION}


##############################
## Resource Group Deploy ##
##############################
CATEGORY=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${CATEGORY}
CONTAINER='rexray'

tput setaf 2; echo "Creating the $RESOURCE_GROUP resource group..." ; tput sgr0
CreateResourceGroup ${RESOURCE_GROUP} ${AZURE_LOCATION};
az group show --name ${RESOURCE_GROUP} -ojsonc

tput setaf 2; echo "Deploying Template..." ; tput sgr0
az group deployment create \
  --resource-group ${RESOURCE_GROUP} \
  --template-file arm-templates/deployAzure.json \
  --parameters @arm-templates/deployAzure.params.json \
  --parameters unique=${UNIQUE} serverCount=${COUNT}\
  -ojsonc

tput setaf 2; echo "Creating the $CONTAINER blob container..." ; tput sgr0
STORAGE_ACCOUNT=$(GetStorageAccount $RESOURCE_GROUP)
CONNECTION=$(GetStorageConnection $RESOURCE_GROUP $STORAGE_ACCOUNT)
CreateBlobContainer $CONTAINER $CONNECTION

tput setaf 2; echo "Creating the REX-ray Service Principal..." ; tput sgr0
PRINCIPAL=$(CreateAdServicePrincipal ${RESOURCE_GROUP})

##############################
## Create Ansible Inventory ##
##############################
BASE_PORT=5000
INVENTORY="./ansible/inventories/azure/"
GLOBAL_VARS="./ansible/inventories/azure/group_vars"
mkdir -p ${INVENTORY};
mkdir -p ${GLOBAL_VARS}

tput setaf 2; echo "Retrieving Ansible Required Information ..." ; tput sgr0

TENANT=$(az account show \
  --subscription ${AZURE_SUBSCRIPTION} \
  --query tenantId \
  -otsv)

STORAGE_KEY=$(az storage account keys list \
  --account-name ${STORAGE_ACCOUNT} \
  --resource-group ${RESOURCE_GROUP} \
  --query '[0].value' \
  -otsv)

STORAGE_CONTAINER=$(az storage container list \
  --account-name ${STORAGE_ACCOUNT} \
  --account-key ${STORAGE_KEY} \
  --query "[?name!='vhds'].name" \
  -otsv)

LB_IP=$(az network public-ip show \
  --resource-group ${RESOURCE_GROUP} \
  --name lb-ip \
  --query ipAddress \
  -otsv)

# Ansible Inventory
tput setaf 2; echo 'Creating the ansible inventory files...' ; tput sgr0
cat > ${INVENTORY}/hosts << EOF
$(for (( c=0; c<$COUNT; c++ )); do echo "vm$c ansible_host=$LB_IP ansible_port=$(($BASE_PORT + $c))"; done)

[manager]

[worker]
EOF

# Ansible Config
tput setaf 2; echo 'Creating the ansible config file...' ; tput sgr0
cat > ansible.cfg << EOF1
[defaults]
inventory = ${INVENTORY}/hosts
private_key_file = .ssh/id_rsa
host_key_checking = false
EOF1

# Ansible Global VARS
tput setaf 2; echo 'Creating the global vars file...' ; tput sgr0
cat > ${GLOBAL_VARS}/all << EOF2
# The global variable file rexray installation

azure_subscriptionid: ${AZURE_SUBSCRIPTION}
azure_tenantid: ${TENANT}
azure_resourcegroup: ${RESOURCE_GROUP}

azure_clientid: $(echo $PRINCIPAL |awk '{print $1'})
azure_clientsecret: $(echo $PRINCIPAL |awk '{print $2'})

azure_storageaccount: ${STORAGE_ACCOUNT}
azure_storageaccesskey: ${STORAGE_KEY}
azure_container: rexray
EOF2
