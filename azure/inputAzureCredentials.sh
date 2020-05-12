#!/bin/bash

YLW='\033[1;33m'
NC='\033[0m'

CREDS_FILE=./creds.json
CREDS_TEMPLATE_FILE=./creds.template

if [ -f "$CREDS_FILE" ]
then
    DT_BASEURL=$(cat creds.json | jq -r '.DT_BASEURL')
    DT_API_TOKEN=$(cat creds.json | jq -r '.DT_API_TOKEN')
    DT_PAAS_TOKEN=$(cat creds.json | jq -r '.DT_PAAS_TOKEN')
    DT_ENVIRONMENT_ID=$(cat creds.json | jq -r '.DT_ENVIRONMENT_ID')
    AZURE_RESOURCE_GROUP=$(cat creds.json | jq -r '.AZURE_RESOURCE_GROUP')
    AZURE_SUBSCRIPTION=$(cat creds.json | jq -r '.AZURE_SUBSCRIPTION')
    AZURE_LOCATION=$(cat creds.json | jq -r '.AZURE_LOCATION')
fi

clear
echo "==================================================================="
echo -e "${YLW}Please enter your Dynatrace credentials as requested below: ${NC}"
echo "Press <enter> to keep the current value"
echo "==================================================================="
echo    "Dynatrace Base URL     (ex. https://ABC.live.dynatrace.com) "
read -p "                       (current: $DT_BASEURL) : " DT_BASEURL_NEW
read -p "Dynatrace Environment  (current: $DT_ENVIRONMENT_ID) : " DT_ENVIRONMENT_ID_NEW
read -p "Dynatrace API Token    (current: $DT_API_TOKEN) : " DT_API_TOKEN_NEW
read -p "Dynatrace PaaS Token   (current: $DT_PAAS_TOKEN) : " DT_PAAS_TOKEN_NEW
#read -p "Azure Resource Group   (current: $AZURE_RESOURCE_GROUP) : " AZURE_RESOURCE_GROUP_NEW
read -p "Azure Subscription     (current: $AZURE_SUBSCRIPTION) : " AZURE_SUBSCRIPTION_NEW
#read -p "Azure Location         (current: $AZURE_LOCATION) : " AZURE_LOCATION_NEW
echo "==================================================================="
echo ""

# set value to new input or default to current value
DT_BASEURL=${DT_BASEURL_NEW:-$DT_BASEURL}
DT_API_TOKEN=${DT_API_TOKEN_NEW:-$DT_API_TOKEN}
DT_PAAS_TOKEN=${DT_PAAS_TOKEN_NEW:-$DT_PAAS_TOKEN}
DT_ENVIRONMENT_ID=${DT_ENVIRONMENT_ID_NEW:-$DT_ENVIRONMENT_ID}
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP_NEW:-$AZURE_RESOURCE_GROUP}
AZURE_SUBSCRIPTION=${AZURE_SUBSCRIPTION_NEW:-$AZURE_SUBSCRIPTION}
AZURE_LOCATION=${AZURE_LOCATION_NEW:-$AZURE_LOCATION}

echo -e "Please confirm all are correct:"
echo ""
echo "Dynatrace Base URL     : $DT_BASEURL"
echo "Dynatrace Environment  : $DT_ENVIRONMENT_ID"
echo "Dynatrace API Token    : $DT_API_TOKEN"
echo "Dynatrace PaaS Token   : $DT_PAAS_TOKEN"
echo "Azure Subscription     : $AZURE_SUBSCRIPTION"
echo "Azure Resource Group   : $AZURE_RESOURCE_GROUP"
echo "Azure Location         : $AZURE_LOCATION"
echo "==================================================================="
read -p "Is this all correct? (y/n) : " -n 1 -r
echo ""
echo "==================================================================="

if [[ $REPLY =~ ^[Yy]$ ]]
then
    cp $CREDS_FILE $CREDS_FILE.bak 2> /dev/null
    rm $CREDS_FILE 2> /dev/null

    cat $CREDS_TEMPLATE_FILE | \
      sed 's~AZURE_RESOURCE_GROUP_PLACEHOLDER~'"$AZURE_RESOURCE_GROUP"'~' | \
      sed 's~AZURE_SUBSCRIPTION_PLACEHOLDER~'"$AZURE_SUBSCRIPTION"'~' | \
      sed 's~AZURE_LOCATION_PLACEHOLDER~'"$AZURE_LOCATION"'~' | \
      sed 's~DT_ENVIRONMENT_ID_PLACEHOLDER~'"$DT_ENVIRONMENT_ID"'~' | \
      sed 's~DT_BASEURL_PLACEHOLDER~'"$DT_BASEURL"'~' | \
      sed 's~DT_API_TOKEN_PLACEHOLDER~'"$DT_API_TOKEN"'~' | \
      sed 's~DT_PAAS_TOKEN_PLACEHOLDER~'"$DT_PAAS_TOKEN"'~' > $CREDS_FILE

    echo ""
    echo "Saved credential values to: $CREDS_FILE"
    echo ""
    echo "==================================================================="
    cat $CREDS_FILE
fi
