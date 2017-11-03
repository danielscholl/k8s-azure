#!/usr/bin/env bash
# Copyright (c) 2017, cloudcodeit.com
#
#  Purpose: Add or Remove Load Balancer Rules
#  Usage:
#    lb.sh <unique>

###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: lb.sh <unique> <action> <name> <src:dest>" 1>&2; exit 1; }

if [ -f ~/.azure/.env ]; then source ~/.azure/.env; fi
if [ -f ./.env ]; then source ./.env; fi
if [ -f ./functions.sh ]; then source ./functions.sh; fi

if [ ! -z $1 ]; then UNIQUE=$1; fi
if [ -z $UNIQUE ]; then
  tput setaf 1; echo 'ERROR: UNIQUE not found' ; tput sgr0
  usage;
fi

if [ ! -z $2 ]; then ACTION=$2; fi
if [ ! -z $3 ]; then NAME=$3; fi
if [ ! -z $4 ]; then PORTS=$4; fi


#////////////////////////////////
CATEGORY=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${CATEGORY}

case $ACTION in
create)
  if [ -z $NAME ]; then
    tput setaf 1; echo 'ERROR: NAME not found' ; tput sgr0
    usage;
  fi
  if [ -z $PORTS ]; then
    tput setaf 1; echo 'ERROR: PORTS not found' ; tput sgr0
    usage;
  fi
  PORT_DEST=${PORTS#*:}
  PORT_SOURCE=${PORTS%:*}

  echo "Creating LB Rule for" ${RESOURCE_GROUP}
  CreateLoadBalancerRule $NAME $PORT_SOURCE $PORT_DEST
  IP=$(az network public-ip list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'lb-ip')].ipAddress" -otsv)

  echo "http://${IP}:${PORT_SOURCE}"
  ;;
rm)
  if [ -z $NAME ]; then
    tput setaf 1; echo 'ERROR: NAME not found' ; tput sgr0
    usage;
  fi
  echo "Removing LB Rule for" ${RESOURCE_GROUP}
  RemoveLoadBalancerRule $NAME
  ;;
ls)
  echo "List LB Rules" ${RESOURCE_GROUP}
  LB_NAME=$(GetLoadBalancer $RESOURCE_GROUP)
  az network lb rule list \
      --resource-group $RESOURCE_GROUP \
      --lb-name $LB_NAME \
      --query '[].{name:name, "LB Port":frontendPort, "Swarm Port":backendPort, protocol:protocol}' \
      -otable
  ;;
*)
  usage
  ;;
esac
