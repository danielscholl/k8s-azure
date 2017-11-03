#!/usr/bin/env bash
# Copyright (c) 2017, cloudcodeit.com
#
#  Purpose: Delete the Azure Resources
#  Usage:
#    clean.sh <unique>


###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: install.sh <unique>" 1>&2; exit 1; }

if [ -f ~/.azure/.env ]; then source ~/.azure/.env; fi
if [ -f ./.env ]; then source ./.env; fi

if [ ! -z $1 ]; then UNIQUE=$1; fi
if [ -z $UNIQUE ]; then
  tput setaf 1; echo 'ERROR: UNIQUE not found' ; tput sgr0
  usage;
fi

#####################################
## Remove Temporary Resource Group ##
#####################################
CATEGORY=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${CATEGORY}

tput setaf 2; echo "Removing the $RESOURCE_GROUP resource group..." ; tput sgr0
az group delete --name ${RESOURCE_GROUP} --no-wait --yes

if [ -f inventory ]; then rm inventory; fi
if [ -f playbook.retry ]; then rm playbook.retry; fi
