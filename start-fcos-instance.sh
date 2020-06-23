#!/bin/bash

#
# This script provisions a Fedora CoreOS with the minimum tooling needed
# to run Ansible (i.e. python).
#

type aws > /dev/null
if [ $? != 0 ]; then
  echo "Install aws CLI."
  exit
fi

type curl > /dev/null
if [ $? != 0 ]; then
  echo "Install curl."
  exit
fi

type docker > /dev/null
if [ $? != 0 ]; then
  echo "Install docker."
  exit
fi

type jq > /dev/null
if [ $? != 0 ]; then
  echo "Install jq."
  exit
fi

ENABLE_RPM_OSTREE=1

#
# Visit the following URL to determine the AMI that you want to start.
#   https://getfedora.org/en/coreos/download?tab=cloud_launchable&stream=stable
#
# You can use the following commands to alway pull the newest AMI.
#   JSON_URL="https://builds.coreos.fedoraproject.org/streams/stable.json"
#   AMI=$(curl -s $JSON_URL | jq -r '.architectures.x86_64.images.aws.regions["us-east-1"].image')
#
# The AMI is hard-coded because this project tries to pass Lydis tests and I 
# don't want a moving target.

AMI="ami-0ac9fa195c3a98c56"    # 32.20200601.3.0 stable

#AMI="ami-0d42d687e65a2f5bf"

LYNIS_HARDENING_SCORE=$(aws ec2 describe-images --image-ids $AMI --query 'Images[].Tags[?Key==`lynis-hardening-score`].Value[]' --output text)
if [ ! -z $LYNIS_HARDENING_SCORE ]; then
  # The AMI was previously created by this script so some steps can be avoided.
  ENABLE_RPM_OSTREE=0
fi

echo "LYNIS_HARDENING_SCORE: $LYNIS_HARDENING_SCORE"
echo "ENABLE_RPM_OSTREE: $ENABLE_RPM_OSTREE"

AWS_PROFILE="ic1"
AWS_REGION="us-east-1"
INSTANCE_TYPE="t3.medium"
IGNITION_FILE_BASE="lynis"
KEY_NAME="david-va-oit-cloud-k8s"
SECURITY_GROUP_ID="sg-0a4ad278f69b3d617"  # allow-world-ssh
SUBNET_ID="subnet-02c78f939d58e2320"
PKI_PRIVATE_PEM=/home/medined/Downloads/pem/david-va-oit-cloud-k8s.pem
PKI_PUBLIC_PUB=/home/medined/Downloads/pem/david-va-oit-cloud-k8s.pub
SSM_BINARY_DIR=/data/projects/dva/amazon-ssm-agent/bin/linux_amd64
SSH_USER=core

#
# Sanity Checks
#

if [ ! -d $SSM_BINARY_DIR ]; then
  echo "Missing directory: $SSM_BINARY_DIR"
  exit
fi

if [ ! -f $PKI_PRIVATE_PEM ]; then
    echo "Missing private key file: $PKI_PRIVATE_PEM"
    exit
fi
if [ ! -f $PKI_PUBLIC_PUB ]; then
    echo "Missing public key file: $PKI_PUBLIC_PUB"
    exit
fi

aws ec2 describe-security-groups \
  --region $AWS_REGION \
  --group-ids $SECURITY_GROUP_ID \
  --query 'SecurityGroups[0].GroupId' | grep $SECURITY_GROUP_ID

if [ $? != 0 ]; then
  echo "Missing security group: $SECURITY_GROUP_ID"
  exit
fi

aws ec2 describe-subnets \
  --region $AWS_REGION \
  --subnet-ids $SUBNET_ID \
  --query 'Subnets[0].SubnetId' | grep $SUBNET_ID

if [ $? != 0 ]; then
  echo "Missing subnet: $SUBNET_ID"
  exit
fi

PKI_PUBLIC_KEY=$(cat $PKI_PUBLIC_PUB)

#
# While it is possible to create files using the Ignition file,
# you can't write onto a read-only file like /etc/issue. Trying 
# only provisions a broken server that you can't SSH into.
#
# https://coreos.com/os/docs/latest/update-strategies.html talks
# about update-engine.service and locksmithd.service files but those 
# are not on the FCOS image that we are using. As far as I know,
# Zincatti is the update mechanism.

cat <<EOF > $IGNITION_FILE_BASE.fcc
variant: fcos
version: 1.0.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - $PKI_PUBLIC_KEY
systemd:
  units:
    - name: docker.service
      enabled: true
# storage:
#   files:
#     - path: /etc/issue.d/80_warning.issue
#       contents:
#         inline: |
#           This is a secure server.
#           Are you here by owner consent?
#           Unless you have been invited, access is prohibited. 
#           This is your last warning. 
#           All activities are monitored.
EOF

echo "Pulling fcc compiler from quay.io."
docker pull quay.io/coreos/fcct:release

echo "Compiling fcc file into an ign file."
docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < $IGNITION_FILE_BASE.fcc > $IGNITION_FILE_BASE.ign

if [ $? != 0 ]; then
  echo "ERROR: Unable to compile FCC file."
  exit 1
fi

INSTANCE_NAME="fcos-$(date +%Y%m%d%H%M%S)"

echo "Starting instance."
INSTANCE_ID=$(aws ec2 run-instances \
  --associate-public-ip-address \
  --count 1 \
  --image-id $AMI \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --region $AWS_REGION \
  --security-group-ids $SECURITY_GROUP_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --user-data file://$IGNITION_FILE_BASE.ign \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Waiting for instance."
aws ec2 wait system-status-ok --instance-ids $INSTANCE_ID --region $AWS_REGION
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID --region $AWS_REGION

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --output text \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --region $AWS_REGION)

echo "remove existing ssh fingerprint."
ssh-keygen -R $PUBLIC_IP > /dev/null 2>&1
echo "get ssh fingerprint."
ssh-keyscan -H $PUBLIC_IP >> ~/.ssh/known_hosts 2>/dev/null

echo "Install packages one by one. More specific errors this way."
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install python libselinux-python3"

echo "reboot instance."
aws ec2 reboot-instances --instance-ids $INSTANCE_ID --region $AWS_REGION
echo "waiting for reboot command to process"
sleep 10

./test-ssh.sh $PUBLIC_IP $PKI_PRIVATE_PEM $SSH_USER

echo "create inventory."
cat <<EOF >inventory
[fcos]
$PUBLIC_IP
EOF

echo "display variables."
cat <<EOF
AWS_REGION=$AWS_REGION
INSTANCE_ID=$INSTANCE_ID
PKI_PRIVATE_PEM=$PKI_PRIVATE_PEM
PUBLIC_IP=$PUBLIC_IP
SSH_USER=$SSH_USER
EOF

echo
echo "ssh -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP"
echo
