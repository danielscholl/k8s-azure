###############################
## FUNCTIONS                 ##
###############################
function CreateResourceGroup() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LOCATION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (LOCATION) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az group show --name $1)
  if [ "$_result"  == "" ]
    then
      OUTPUT=$(az group create --name $1 \
        --location $2 \
        -ojsonc)
    else
      tput setaf 3;  echo "Resource Group $1 already exists."; tput sgr0
    fi
}
function CreateStorageAccount() {
  # Required Argument $1 = RESOURCE_GROUP

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi

  local _storage=$(az group deployment create \
    --resource-group $1 \
    --template-file 'templates/nested/deployStorageAccount.json' \
    --query [properties.outputs.storageAccount.value.name] -otsv)

  echo $_storage
}
function GetStorageAccount() {
  # Required Argument $1 = RESOURCE_GROUP

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received' ; tput sgr0
    exit 1;
  fi

  local _storage=$(az storage account list --resource-group $1 --query [].name -otsv)
  echo ${_storage}
}
function GetStorageConnection() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = STORAGE_ACCOUNT

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (STORAGE_ACCOUNT) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az storage account show-connection-string \
    --resource-group $1 \
    --name $2\
    --query connectionString \
    --output tsv)

  echo $_result
}
function CreateBlobContainer() {
  # Required Argument $1 = CONTAINER_NAME
  # Required Argument $2 CONNECTION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (CONTAINER_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (STORAGE_CONNECTION) not received' ; tput sgr0
    exit 1;
  fi

 az storage container create --name $1 \
    --connection-string $2 \
    -ojsonc
}
function CreateSASToken() {
  # Required Argument $1 CONTAINER_NAME
  # Required Argument $2 = CONNECTION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (CONTAINER_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (CONNECTION) not received' ; tput sgr0
    exit 1;
  fi

  local _expire=$(date -v+30M -u +%Y-%m-%dT%H:%MZ)
  local _token=$(az storage container generate-sas --name $1 \
  --expiry ${_expire} \
  --permissions r \
  --connection-string $2 \
  --output tsv)
  echo ${_token}
}
function CreateAdServicePrincipal() {
  # Required Argument $1 = RESOURCE_GROUP

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (ResourceGroup) not received' ; tput sgr0
    exit 1;
  fi

  KV=$(az keyvault list --resource-group $1 --query [].name -otsv)

  local _result=$(az ad sp list --query "[?displayName=='$1']".appId -otsv)
  if [ "$_result"  == "" ]
    then
      PRINCIPAL=$(az ad sp create-for-rbac \
        --name $1 \
        --role "Contributor" \
        --query "[appId, password]" \
        -otsv)

      SECRET=$(az keyvault secret set \
        --vault-name ${KV} \
        --name clientSecret \
        --value $(echo $PRINCIPAL |awk '{print $2'}))

      echo ${PRINCIPAL}
    else
      SECRET=$(az keyvault secret show \
        --vault-name ${KV} \
        --name clientSecret \
        --query value \
        -otsv)
       echo $_result $SECRET
    fi
}
function GetUrl() {
  # Required Argument $1 = BLOB_NAME
  # Required Argument $2 = TOKEN
  # Required Argument $3 CONTAINER_NAME
  # Required Argument $4 = CONNECTION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (BLOB_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (TOKEN) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $3 ]; then
    tput setaf 1; echo 'ERROR: Argument $3 (CONTAINER_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $4 ]; then
    tput setaf 1; echo 'ERROR: Argument $4 (CONNECTION) not received' ; tput sgr0
    exit 1;
  fi

  local _url=$(az storage blob url --name $1.json \
    --container-name $3 \
    --connection-string $4 \
    --output tsv)
  echo ${_url}?$2
}
function GetParams() {
  # Required Argument $1 = TOKEN

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (TOKEN) not received' ; tput sgr0
    exit 1;
  fi

  local _params="uniquePrefix=${UNIQUE} sasToken=?$1"

  echo ${_params}
}
function CreateVirtualMachine() {
  # Required Argument $1 = VM_NAME
  # Required Argument $2 = RESOURCE_GROUP

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (VM_NAME) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi


  local _result=$(az vm show --name $1 --resource-group $2 -ojsonc)
  if [ "$_result"  == "" ]
    then
      az vm create -n $1 --resource-group $2 --image UbuntuLTS -ojsonc
    else
      tput setaf 3;  echo "Virtual Machine $1 already exists."; tput sgr0
    fi
}
function GetLoadBalancer() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LB_NAME

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az network lb list\
    --resource-group $1 \
    --query [].name \
    --output tsv)

  echo $_result
}
function CreateLoadBalancerRule() {
  # Required Argument $1 = NAME
  # Required Argument $2 = PORT_SOURCE
  # Required Argument $3 = PORT_DEST

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RULE_NAME) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (PORT_SOURCE) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $3 ]; then
    tput setaf 1; echo 'ERROR: Argument $3 (PORT_DEST) not received'; tput sgr0
    exit 1;
  fi

  LB_NAME=$(GetLoadBalancer $RESOURCE_GROUP)
  PROBE_NAME=probe-$1
  RULE_NAME=rule-$1
  PORT_SOURCE=$2
  PORT_DEST=$3
  SECURITY_NAME=allow-$1

  local _probe=$(az network lb probe show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $PROBE_NAME \
    -ojsonc)

  if [ "$_probe"  == "" ]
    then
      az network lb probe create \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $PROBE_NAME \
        --protocol tcp \
        --port $PORT_DEST \
        -ojsonc
    else
      tput setaf 3;  echo "Skipping Create Probe $1. Already exists."; tput sgr0
    fi

  local _rule=$(az network lb rule show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $RULE_NAME \
    -ojsonc)

  if [ "$_rule"  == "" ]
    then
      az network lb rule create \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $RULE_NAME \
        --probe-name $PROBE_NAME \
        --protocol tcp \
        --frontend-port $PORT_SOURCE \
        --backend-port $PORT_DEST \
        --frontend-ip-name lbFrontEnd \
        --backend-pool-name lbBackEnd \
        -ojsonc
    else
      tput setaf 3;  echo "Skipping Create Rule $1. Already exists."; tput sgr0
    fi

  local _fw=$(az network nsg rule show \
    --resource-group ${RESOURCE_GROUP} \
    --nsg-name subnet-nsg \
    --name $SECURITY_NAME \
    -ojsonc)

  local _highest=$(az network nsg rule list --resource-group ${RESOURCE_GROUP} --nsg-name subnet-nsg --query [].priority -otsv | sort -nr | head -n1)
  local _priority=$((_highest + 10))
  if [ "$_rule"  == "" ]
    then
      az network nsg rule create \
      --resource-group $RESOURCE_GROUP \
      --nsg-name subnet-nsg \
      --name $SECURITY_NAME \
      --direction inbound \
      --access allow \
      --protocol tcp \
      --source-address-prefix '*' \
      --source-port-range '*' \
      --destination-address-prefix '*' \
      --destination-port-range $PORT_DEST \
      --priority $_priority

    else
      tput setaf 3;  echo "Skipping Security Rule $1. Already exists."; tput sgr0
    fi


}
function RemoveLoadBalancerRule() {
  # Required Argument $1 = NAME
  # Required Argument $2 = PORT_SOURCE
  # Required Argument $3 = PORT_DEST

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RULE_NAME) not received'; tput sgr0
    exit 1;
  fi

  LB_NAME=$(GetLoadBalancer $RESOURCE_GROUP)
  PROBE_NAME=probe-$1
  RULE_NAME=rule-$1
  SECURITY_NAME=allow-$1

  local _rule=$(az network lb rule show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $RULE_NAME \
    --query name \
    -ojsonc)

  if [ "$_rule"  != "" ]
    then
      tput setaf 3;  echo "Delete Rule: $RULE_NAME"; tput sgr0
      az network lb rule delete \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $RULE_NAME \
        -ojsonc
    fi

  local _probe=$(az network lb probe show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $PROBE_NAME \
    --query name \
    -ojsonc)

  if [ "$_probe"  != "" ]
    then
      tput setaf 3;  echo "Delete Probe: $PROBE_NAME"; tput sgr0
      az network lb probe delete \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $PROBE_NAME \
        -ojsonc
    fi

  local _fw=$(az network nsg rule show \
    --resource-group ${RESOURCE_GROUP} \
    --nsg-name ${NSG} \
    --name $SECURITY_NAME \
    -ojsonc)

  if [ "$_fw"  != "" ]
    then
      tput setaf 3;  echo "Delete Inbound Security Rule: $SECURITY_NAME"; tput sgr0
      az network nsg rule delete \
        --resource-group ${RESOURCE_GROUP} \
        --nsg-name subnet-nsg \
        --name $SECURITY_NAME \
        -ojsonc
    fi
}
