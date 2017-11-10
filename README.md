# k8s-azure

This is an Azure environment created using ARM templates with REX-Ray `Virtual Media` 
as a persistent volume store for a kubernetes cluster.  This solution can be used as a quick 
way to get started and learn how a kubernetes swarm works with _persistant storage_ capability.

_** The purpose of this automation solution instead of just using ACS was to implement REX-ray._
> REX-ray is not compatable with Managed Disk Virtual Machines and has to be classic disks. 

__Requirements:__

- Azure Subscription
- Azure CLI (2.0)
- Ansible (2.3.1.0)
- Python 2 or 3 _* 'See OS Modifications'_

## Installation
### Clone the repo

```
git clone https://github.com/danielscholl/k8s-azure
cd k8s-azure
```

### Create the private ssh keys

Access to the servers is via a private ssh session and requires the user to create the SSH Keys in the .ssh directory.

```bash
mkdir .ssh && cd .ssh
ssh-keygen -t rsa -b 2048 -C "azureuser@email.com" -f id_rsa
```


### Create the Environment File

The solution reads environment variables and sources either ~/.azure/.env or {pwd}/.env to retrieve required settings.

Copy the .env_sample to .env and edit to set the required environment variables


```bash
export AZURE_SUBSCRIPTION=<your_subscription_id>
export AZURE_LOCATION=<region_location>
```

### Create the template deploy parameter file

Copy the deployAzure.params_sample.json file to deployAzure.params.json located in the arm-templates directory.

4 parameter values are required in order to begin.

- adminUser (Logged in User of your local machine)
  - __Command:__ `whoami`

- adminSSHKey (Public SSH key of your local machine user)
  - __Command:__  `cat ~/.ssh/id_rsa.pub`

- remoteAccessACL: (Public IP Address of your local machine to be used to grant firewall ssh access)
  - __Command:__ `curl ifconfig.co`

- servicePrincipalAppId  (Object ID of your user to be used for access to KeyVaults)
  - __Command:__ `az ad user show --upn user@email.com`

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "servicePrincipalAppId": {
      "value": "<your_principle_guid>"
    },
    "adminUser": {
      "value": "<whoami>"
    },
    "adminSSHKey": {
      "value": "<your_ssh_key>"
    },
    "vnetPrefix": {
      "value": "10.1.0.0/24"
    },
    "subnetPrefix": {
      "value": "10.1.0.0/25"
    },
    "remoteAccessACL": {
      "value": "<your_host_ip>"
    },
    "serverNamePrefix": {
      "value": "vm"
    },
    "serverSize": {
      "value": "Standard_A1"
    },
    "storageAccountType": {
      "value": "Standard_LRS"
    }
  }
}
```

### OS Specific Modifications

This solution requires python on the localhost and the location is specified currently in the playbook.  If your python is located in an alternate location you will have to modify the playbook.

__File:__ playbooks/roles/reboot-server/tasks/main.yml
__Value:__ ansible_python_interpreter: "/usr/local/bin/python"


### Provision IaaS using ARM Template scripts

The first step is to deploy the custom ARM Templates using the init.sh script.  The script has two required arguments.

- unique (A small unique string necessary for DNS uniqueness in Azure)
- count (The number of Nodes desired to be created  ie: 3)

```bash
./init.sh abc 3
```


### Configure the IaaS servers using Ansible Playbooks

Once the template is deployed properly a few Azure CLI commands are run to create the items not supported by ARM Templates.

1. A Storage Container is created for the REX-ray driver to use.
2. A Service Principle is created with a clientID and clientSecret for the REX-ray driver to use to access AZURE.

Three files are automatically created to support the ansible installation process with the proper values.

#### Ansible Configuration File 

This is the default ansible configuration file that is used by the provisioning process it identifies the location of the ssh keys and where the inventory file is located at.

```yaml
[defaults]
inventory = ./ansible/inventories/azure//hosts
private_key_file = .ssh/id_rsa
host_key_checking = false
```

#### Ansible Hosts File

- ansible/inventories/hosts  (IP Address list of all the Azure Swarm Servers)
- ansible/inventories/azure/group_vars/all  (Global Variable file with custom rexray settings)

An azure host inventory file (./ansible/inventories/azure/hosts) is automatically created but ansible groups must be specified for which nodes are desired to be managers or workers as shown below in sample hosts file.

```yaml
[all]
a.a.a.a
b.b.b.b
c.c.c.c
d.d.d.d
e.e.e.e
f.f.f.f

[manager]
a.a.a.a
b.b.b.b

[workers]
c.c.c.c
d.d.d.d
e.e.e.e
f.f.f.f
```

#### Ansible Group Variable File.

To properly deploy the REX-ray role variables are necessary to be located in the ./ansible/inventories/azure/group_vars/all file which will allow communication by REX-ray to the Azure Storage Account `REXray` container for persistent volumes. 

```yaml
# The global variable file rexray installation

azure_subscriptionid: <your_subscription_id>
azure_tenantid: <your_tenant_id>
azure_resourcegroup: <your_resource_group>

azure_clientid: <your_app_serviceprinciple_id>
azure_clientsecret: <your_app_serviceprinciple_secret>

azure_storageaccount: <your_azure_storage_account>
azure_storageaccesskey: <your_azure_storage_key>
azure_container: <your_azure_container>
```

### Validate Connectivity

Check and validate ansible connectivity once provisioning has been completed you can manually init the cluster.

```bash
ansible all -m ping  #Check Connectivity
ansible-playbook ansible/playbooks/main.yml  # Provision the node Servers

```

## Script Usage

- init.sh _unique_ _count_ (provision IaaS into azure)
- clean.sh _unique_ _count_ (delete IaaS from azure)
- connect.sh _unique_ _node_ (SSH Connect to the node instance)
- manage.sh _unique_ _command_ (deprovision/start/stop nodes in azure)
- lb.sh _unique_ (manage loadbalancer ports to the swarm)
  - lb.sh _unique_ ls  (list all lb rules)
  - lb.sh _unique_ create _name_ _portSrc:portDest_  (ie: create http 80:8080 --> Open port 80 map to 8080 on swarm and name it http)
  - lb.sh _unique_ rm _name_ (remove lb rule)

## REX-Ray
Consult the full REX-Ray documentation [here](http://rexray.readthedocs.org/en/stable/).

List Volumes:

`sudo rexray volume ls`

Create a new volume:

`sudo rexray volume create --size=1 testVolume`

Delete a volume:

`sudo rexray volume rm b4219d9e-c835-431f-8ed8-a7f4a3838ddf`

## Docker
Consult the Docker documentation [here](https://docs.docker.com/engine/admin/volumes/volumes/#choosing-the--v-or-mount-flag).  

You can also create volumes directly from the Docker CLI.  The following command created a volume of `1GB` size with name of `testVolume`.

```
docker volume create --driver=rexray --opt=size=1 testVolume
```

Start a new container with a REX-Ray volume attached, and detach the volume when the container stops:

```
docker run -it --volume-driver=rexray -v testVolume:/data busybox /bin/sh
# ls /
bin   dev   etc   home  proc  root  sys   *data*  tmp   usr   var
# exit
```

>Note: Volumes are exposed across all nodes in the swarm.
