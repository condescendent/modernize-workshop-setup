#!/bin/bash

CREDS_FILE=creds.json
if ! [ -f "$CREDS_FILE" ]; then
  echo "ERROR: missing $CREDS_FILE"
  exit 1
fi

DT_BASEURL=$(cat $CREDS_FILE | jq -r '.DT_BASEURL')
DT_PAAS_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_PAAS_TOKEN')
AWS_PROFILE=$(cat creds.json | jq -r '.AWS_PROFILE')
AWS_REGION=$(cat creds.json | jq -r '.AWS_REGION')
AWS_KEYPAIR_NAME=$(cat creds.json | jq -r '.AWS_KEYPAIR_NAME')
RESOURCE_PREFIX=$(cat creds.json | jq -r '.RESOURCE_PREFIX')
STACK_NAME="$RESOURCE_PREFIX-dynatrace-modernize-workshop"

create_stack() 
{

  echo ""
  echo "-----------------------------------------------------------------------------------"
  echo "Creating CloudFormation Stack $STACK_NAME"
  echo "-----------------------------------------------------------------------------------"

  aws cloudformation create-stack \
      --stack-name $STACK_NAME \
      --profile $AWS_PROFILE \
      --region $AWS_REGION \
      --template-body file://workshopCloudFormationTemplate.yaml \
      --parameters \
          ParameterKey=KeyName,ParameterValue=$AWS_KEYPAIR_NAME \
          ParameterKey=LastName,ParameterValue=$RESOURCE_PREFIX \
          ParameterKey=DynatraceBaseURL,ParameterValue=$DT_BASEURL \
          ParameterKey=DynatracePaasToken,ParameterValue=$DT_PAAS_TOKEN \
      --capabilities CAPABILITY_NAMED_IAM
}

load_dynatrace_config()
{
  # workshop config like tags, dashboard, MZ
  # doing this change directory business, so that can share script across AWS and Azure
  cp creds.json ../dynatrace/creds.json
  cd ../dynatrace
  ./setupWorkshopConfig.sh
  cd ../aws
}

add_aws_keypair()
{
  # add the keypair needed for ec2 if it does not exist
  AWS_KEYPAIR_NAME=$(cat creds.json | jq -r '.AWS_KEYPAIR_NAME')
  KEY=$(aws ec2 describe-key-pairs \
    --profile $AWS_PROFILE \
    --region $AWS_REGION | grep $AWS_KEYPAIR_NAME)
  if [ -z "$KEY" ]; then
    echo "Creating a keypair named $AWS_KEYPAIR_NAME for the ec2 instances"
    echo "Saving output to $AWS_KEYPAIR_NAME-keypair.json"
    aws ec2 create-key-pair \
      --key-name $AWS_KEYPAIR_NAME \
      --profile $AWS_PROFILE \
      --region $AWS_REGION \
      --query 'KeyMaterial' \
      --output text > gen/$AWS_KEYPAIR_NAME-keypair.pem

    # adjust permissions required for ssh
    chmod 400 gen/$AWS_KEYPAIR_NAME-keypair.pem
  else
    echo "Skipping, add key-pair $AWS_KEYPAIR_NAME since it exists"
  fi
}

############################################################
echo "==================================================================="
echo "About to provision AWS workshop resources"
echo ""
echo "1) Add Dynatrace configuration to: $DT_BASEURL"
echo "2) Add AWS keypair: $AWS_KEYPAIR_NAME"
echo "3) Create AWS CLoudformation stack: $STACK_NAME"
echo "==================================================================="
read -p "Proceed with creation? (y/n) : " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then

  echo ""
  echo "=========================================="
  echo "Provisioning AWS workshop resources"
  echo "Starting: $(date)"
  echo "=========================================="

  load_dynatrace_config
  add_aws_keypair
  create_stack

  echo ""
  echo "============================================="
  echo "Provisioning AWS workshop resources COMPLETE"
  echo "End: $(date)"
  echo "============================================="
  echo ""
  echo "Monitor CloudFormation stack status @ https://console.aws.amazon.com/cloudformation/home"
  echo ""
  echo "If you need to SSH to host, get the public IP from the AWS console and use"
  echo "ssh -i \"gen/$AWS_KEYPAIR_NAME-keypair.pem\" ubuntu@PUBLIC_IP"

fi