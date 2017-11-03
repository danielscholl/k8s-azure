#!/usr/bin/env bash
# Copyright (c) 2017, cloudcodeit.com
#
#  Purpose: SSH Connect to the Azure Virtual Machine
#  Usage:
#    connect.sh <unique>

###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: connect.sh <unique> <instance>" 1>&2; exit 1; }

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
if [ ! -z $2 ]; then INSTANCE=$2; fi
if [ -z $INSTANCE ]; then
  INSTANCE=0
fi

#////////////////////////////////
CATEGORY=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${CATEGORY}

echo "Retrieving IP Address for vm${INSTANCE} in " ${RESOURCE_GROUP}
IP=$(az network public-ip show --resource-group ${RESOURCE_GROUP} --name lb-ip --query ipAddress -otsv)
echo 'Connecting to' $USER@$IP

SSH_KEY="~/.ssh/id_rsa"
if [ -f .ssh/id_rsa ]; then
  SSH_KEY=".ssh/id_rsa"
fi

PORT=$((5000 + $INSTANCE))
ssh -i ${SSH_KEY} $USER@$IP -A -p $PORT
