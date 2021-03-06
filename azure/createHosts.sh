#!/bin/bash

#*********************************
# Reference: 
# Dynatrace: https://www.dynatrace.com/support/help/technology-support/cloud-platforms/microsoft-azure/azure-services/virtual-machines/deploy-oneagent-on-azure-virtual-machines
# Azure:     https://docs.microsoft.com/en-us/cli/azure/vm?view=azure-cli-latest#az-vm-create
#*********************************
HOST_TYPE=$1               # 'linux','win',ez'
NUM_HOSTS=$2
ADD_EZTRAVEL_ONEAGENT=$3   # only for eztravel, pass in 'yes' if want agent added

# Example: 1 host running ezTravel with no OneAgent :  ./createHosts.sh ez
# Example: 2 host running ezTravel with OneAgent    :  ./createHosts.sh ez 1 yes
# Example: 5 linux host                             :  ./createHosts.sh linux 5
# Example: 5 windows hosts                          :  ./createHosts.sh win 5

CREDS_FILE=creds.json
if ! [ -f "$CREDS_FILE" ]; then
  echo "ERROR: missing $CREDS_FILE"
  exit 1
fi

if [ -z $2 ]; then
  NUM_HOSTS=1
fi

AZURE_RESOURCE_GROUP=$(cat $CREDS_FILE | jq -r '.AZURE_RESOURCE_GROUP')
AZURE_SUBSCRIPTION=$(cat $CREDS_FILE | jq -r '.AZURE_SUBSCRIPTION')
AZURE_LOCATION=$(cat $CREDS_FILE | jq -r '.AZURE_LOCATION')
DT_ENVIRONMENT_ID=$(cat $CREDS_FILE | jq -r '.DT_ENVIRONMENT_ID')
DT_BASEURL=$(cat $CREDS_FILE | jq -r '.DT_BASEURL')
DT_PAAS_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_PAAS_TOKEN')
DT_API_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_API_TOKEN')

#*********************************
does_vm_exist()
{
  if [ -z $(az vm get-instance-view -g $AZURE_RESOURCE_GROUP -n $HOSTNAME --subscription $AZURE_SUBSCRIPTION --query vmId) ]; then
    echo false
  else
    echo true
  fi
}

#*********************************
# https://www.dynatrace.com/support/help/technology-support/cloud-platforms/microsoft-azure/azure-services/virtual-machines/deploy-oneagent-on-azure-virtual-machines/
# can add , \"enableLogsAnalytics\":\"yes\"
add_oneagent_extension()
{
  AGENT=$1  # values oneAgentLinux,oneAgentWindows
  HOSTGROUP_NAME=$2
  echo ""
  echo "Adding OneAgent extension for $HOSTNAME"

  EXTENTION_STATUS="$(az vm extension set \
    --publisher dynatrace.ruxit \
    --name "$AGENT" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --subscription "$AZURE_SUBSCRIPTION" \
    --vm-name "$HOSTNAME" \
    --settings "{\"tenantId\":\"$DT_ENVIRONMENT_ID\",\"token\":\"$DT_PAAS_TOKEN\", \"server\":\"$DT_BASEURL/api\", \"hostGroup\":\"$HOSTGROUP_NAME\"}" \
    | jq -r '.provisioningState')"
    
  echo "Extension Installation Status: $EXTENTION_STATUS"
  echo ""
}

#*********************************
create_resource_group()
{
  # only create if it does not exist
  if [ -z $(az group show -n $AZURE_RESOURCE_GROUP --subscription $AZURE_SUBSCRIPTION --query id) ]; then
    echo "Creating resource group: $AZURE_RESOURCE_GROUP"
    az group create \
      --location "$AZURE_LOCATION" \
      --name "$AZURE_RESOURCE_GROUP" \
      --subscription "$AZURE_SUBSCRIPTION"
  else
    echo "Using resource group $AZURE_RESOURCE_GROUP"
  fi
}

#*********************************
provision_linux_active_gate()
{
  HOSTGROUP=$1
  HOSTNAME="workshop-active-gate-$HOSTGROUP"

  # make cloud-init with users API and TOKEN info
  ACTIVATE_GATE_FILE="cloud-init-active-gate.txt"

  echo "#cloud-config" > $ACTIVATE_GATE_FILE
  echo "runcmd:" >> $ACTIVATE_GATE_FILE
  echo "  - wget -O /tmp/Dynatrace-ActiveGate-Linux-x86-1.193.130.sh \"$DT_BASEURL/api/v1/deployment/installer/gateway/unix/latest?arch=x86&flavor=default\" --header=\"Authorization:Api-Token $DT_PAAS_TOKEN\"" >> $ACTIVATE_GATE_FILE
  echo "  - sudo /bin/sh /tmp/Dynatrace-ActiveGate-Linux-x86-1.193.130.sh" >> $ACTIVATE_GATE_FILE
  echo "" >> $ACTIVATE_GATE_FILE

  echo "Checking if $HOSTNAME already exists"
  if [ "$(does_vm_exist)" == "true" ]; then
    echo "Skipping, host $HOSTNAME exists"
    echo ""
  else
    echo ""
    echo "Provisioning $HOSTNAME"

    VM_STATE="$(az vm create \
      --name "$HOSTNAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --image "UbuntuLTS" \
      --custom-data "$ACTIVATE_GATE_FILE" \
      --tags Owner=azure-modernize-workshop \
      --subscription "$AZURE_SUBSCRIPTION" \
      --location "$AZURE_LOCATION" \
      --authentication-type password \
      --admin-username azureuser \
      --admin-password Azureuser123# \
      --size Standard_B1ms \
      | jq -r '.powerState')"

    echo "VM State: $VM_STATE"
    if [ "$VM_STATE" != "VM running" ]; then
      echo "Aborting due to VM creation error."
      break
    else
      echo ""
      #add_oneagent_extension oneAgentLinux active-gate
    fi
  fi
}

#*********************************
#      --custom-data cloud-init.txt \
provision_linux_vm()
{
  HOSTGROUP=$1
  HOSTNAME="workshop-linux-$HOSTGROUP"

  echo "Checking if $HOSTNAME already exists"
  if [ "$(does_vm_exist)" == "true" ]; then
    echo "Skipping, host $HOSTNAME exists"
    echo ""
  else
    echo ""
    echo "Provisioning $HOSTNAME"

    VM_STATE="$(az vm create \
      --name "$HOSTNAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --image "UbuntuLTS" \
      --tags Owner=azure-modernize-workshop \
      --subscription "$AZURE_SUBSCRIPTION" \
      --location "$AZURE_LOCATION" \
      --authentication-type password \
      --admin-username azureuser \
      --admin-password Azureuser123# \
      --size Standard_B1ms \
      | jq -r '.powerState')"

    echo "VM State: $VM_STATE"
    if [ "$VM_STATE" != "VM running" ]; then
      echo "Aborting due to VM creation error."
      break
    else
      add_oneagent_extension oneAgentLinux linux
    fi
  fi
}

#*********************************
provision_win_vm()
{
  HOSTGROUP=$1
  HOSTNAME="workshop-win-$HOSTGROUP"

  echo "Checking if $HOSTNAME already exists"
  if [ "$(does_vm_exist)" == "true" ]; then
    echo "Skipping, host $HOSTNAME exists"
    echo ""
  else
    echo ""
    echo "Provisioning $HOSTNAME"

    VM_STATE="$(az vm create \
      --name "$HOSTNAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --image "$IMAGE" \
      --tags Owner=azure-modernize-workshop \
      --size Standard_B1ms \
      --image win2016datacenter \
      --subscription "$AZURE_SUBSCRIPTION" \
      --location "$AZURE_LOCATION" \
      --authentication-type password \
      --admin-username azureuser \
      --admin-password Azureuser123# \
      | jq -r '.powerState')"

    echo "VM State: $VM_STATE"
    if [ "$VM_STATE" != "VM running" ]; then
      echo "Aborting due to VM creation error."
      break
    else
      add_oneagent_extension oneAgentWindows windows
    fi
  fi
}

#*********************************
# cloud-init logs: /var/log/cloud-init.log
#   = 
# Standard_D2s_v3 = 2 vcpus, 8 GiB memory
# Standard_B1ms   = 1 vcpus, 2 GiB memory
provision_eztravel_vm()
{
  HOSTGROUP=$1
  HOSTNAME="workshop-ez-monolith-$HOSTGROUP"

  echo "Checking if $HOSTNAME already exists"
  if [ "$(does_vm_exist)" == "true" ]; then
    echo "Skipping, host $HOSTNAME exists"
    echo ""
  else
    echo ""
    echo "Provisioning $HOSTNAME"
    
    VM_STATE="$(az vm create \
      --name "$HOSTNAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --image UbuntuLTS \
      --tags Owner=azure-modernize-workshop \
      --subscription "$AZURE_SUBSCRIPTION" \
      --location "$AZURE_LOCATION" \
      --custom-data cloud-init-ez.txt \
      --authentication-type password \
      --admin-username workshop \
      --admin-password Workshop123# \
      --size Standard_E2_v3 \
      | jq -r '.powerState')"

    echo "VM State: $VM_STATE"
    if [ "$VM_STATE" != "VM running" ]; then
      echo "Aborting due to VM creation error."
      break
    else
      ## TO DO 
      ## https://docs.microsoft.com/en-us/azure/virtual-machines/linux/nsg-quickstart
      ## https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-cli-complete
      ## az network nsg create
      ## az network nsg rule create
      ## az network nic list
      ## az network nic update

      echo "Opening Ports"
      # Legacy 8080,8079 / Angular 9080 and 80 / WebLauncher (Admin UI) 8094 / REST 8091 / ??? 1697
      # using the proxy Legacy is on port 80
      OPEN_PORT="$(az vm open-port --port 80   --priority 1010 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"
      #OPEN_PORT="$(az vm open-port --port 8080 --priority 1020 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"
      OPEN_PORT="$(az vm open-port --port 8094 --priority 1030 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"
      OPEN_PORT="$(az vm open-port --port 8091 --priority 1040 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"
      #OPEN_PORT="$(az vm open-port --port 8079 --priority 1050 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"
      #OPEN_PORT="$(az vm open-port --port 9080 --priority 1060 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"
      #OPEN_PORT="$(az vm open-port --port 1697 --priority 1070 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"

      if [ "$ADD_EZTRAVEL_ONEAGENT" == "yes" ]; then
        add_oneagent_extension oneAgentLinux eztravel-monolith
      else
        echo "Skipping OneAgent install"
        echo ""
      fi
    fi
  fi
}

#*********************************
# cloud-init logs: /var/log/cloud-init.log
provision_eztravel_backend_vm()
{
  HOSTGROUP=$1
  HOSTNAME="workshop-ez-backend-$HOSTGROUP"

  echo "Checking if $HOSTNAME already exists"
  if [ "$(does_vm_exist)" == "true" ]; then
    echo "Skipping, host $HOSTNAME exists"
    echo ""
  else
    echo ""
    echo "Provisioning $HOSTNAME"
    
    VM_STATE="$(az vm create \
      --name "$HOSTNAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --image UbuntuLTS \
      --tags Owner=azure-modernize-workshop \
      --subscription "$AZURE_SUBSCRIPTION" \
      --location "$AZURE_LOCATION" \
      --custom-data cloud-init-ez-backend.txt \
      --authentication-type password \
      --admin-username workshop \
      --admin-password Workshop123# \
      --size Standard_D2s_v3 \
      | jq -r '.powerState')"

    echo "VM State: $VM_STATE"
    if [ "$VM_STATE" != "VM running" ]; then
      echo "Aborting due to VM creation error."
      break
    else
      ## TO DO 
      ## https://docs.microsoft.com/en-us/azure/virtual-machines/linux/nsg-quickstart
      ## https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-cli-complete
      ## az network nsg create
      ## az network nsg rule create
      ## az network nic list
      ## az network nic update
      
      echo "Opening Ports"
      echo "port 8091 - backend"
      OPEN_PORT="$(az vm open-port --port 8091 --priority 1060 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"

      if [ "$ADD_EZTRAVEL_ONEAGENT" == "yes" ]; then
        add_oneagent_extension oneAgentLinux eztravel-backend
      else
        echo "Skipping OneAgent install"
        echo ""
      fi
    fi
  fi
}

#*********************************
# cloud-init logs: /var/log/cloud-init.log
provision_eztravel_docker_vm()
{
  HOSTGROUP=$1
  HOSTNAME="workshop-ez-docker-$HOSTGROUP"

  echo "Checking if $HOSTNAME already exists"
  if [ "$(does_vm_exist)" == "true" ]; then
    echo "Skipping, host $HOSTNAME exists"
    echo ""
  else
    echo ""
    echo "Provisioning $HOSTNAME"
    
    VM_STATE="$(az vm create \
      --name "$HOSTNAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --image UbuntuLTS \
      --tags Owner=azure-modernize-workshop \
      --subscription "$AZURE_SUBSCRIPTION" \
      --location "$AZURE_LOCATION" \
      --custom-data cloud-init-ez-docker.txt \
      --authentication-type password \
      --admin-username workshop \
      --admin-password Workshop123# \
      --size Standard_E2_v3 \
      | jq -r '.powerState')"

    echo "VM State: $VM_STATE"
    if [ "$VM_STATE" != "VM running" ]; then
      echo "Aborting due to VM creation error."
      break
    else
      ## TO DO 
      ## https://docs.microsoft.com/en-us/azure/virtual-machines/linux/nsg-quickstart
      ## https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-cli-complete
      ## az network nsg create
      ## az network nsg rule create
      ## az network nic list
      ## az network nic update
      
      echo "Opening Ports"
      echo "port 80 - frontend"
      OPEN_PORT="$(az vm open-port --port 80 --priority 1010 --resource-group "$AZURE_RESOURCE_GROUP" --name "$HOSTNAME" --subscription "$AZURE_SUBSCRIPTION")"

      if [ "$ADD_EZTRAVEL_ONEAGENT" == "yes" ]; then
        add_oneagent_extension oneAgentLinux eztravel-docker
      else
        echo "Skipping OneAgent install"
        echo ""
      fi
    fi
  fi
}

#*********************************
echo "==================================================================================="
echo "*** Provisioning $NUM_HOSTS hosts of type $HOST_TYPE ***"
create_resource_group
HOST_CTR=1
while [ $HOST_CTR -le $NUM_HOSTS ]
do

  case $HOST_TYPE in
  linux)
    echo "Provisioning $HOST_TYPE ($HOST_CTR of $NUM_HOSTS): Starting: $(date)"
    provision_linux_vm $HOST_CTR
    ;;
  win)
    echo "Provisioning $HOST_TYPE ($HOST_CTR of $NUM_HOSTS): Starting: $(date)"
    provision_win_vm $HOST_CTR
    ;;
  ez)
    echo "Provisioning $HOST_TYPE ($HOST_CTR of $NUM_HOSTS): Starting: $(date)"
    provision_eztravel_vm $HOST_CTR
    ;;
  ez-backend)
    echo "Provisioning $HOST_TYPE ($HOST_CTR of $NUM_HOSTS): Starting: $(date)"
    provision_eztravel_backend_vm $HOST_CTR
    ;;
  ez-docker)
    echo "Provisioning $HOST_TYPE ($HOST_CTR of $NUM_HOSTS): Starting: $(date)"
    provision_eztravel_docker_vm $HOST_CTR
    ;;
  active-gate)
    echo "Provisioning $HOST_TYPE ($HOST_CTR of $NUM_HOSTS): Starting: $(date)"
    provision_linux_active_gate $HOST_CTR
    ;;
  *) 
    echo "Invalid HOST_TYPE option. Valid values are 'linux','win','ez','ez-backend','active-gate'"
    break
    ;;
  esac
  echo "Complete: $(date)"
  HOST_CTR=$(( $HOST_CTR + 1 ))

done

echo "*** Done. ***"
echo "==================================================================================="
