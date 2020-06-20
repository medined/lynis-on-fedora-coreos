#!/bin/bash

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

if [ ! -f grub-password.txt ]; then
  echo "Missing grub-password.txt file."
  exit
fi

ENABLE_CLOUDWATCH_AGENT=0
ENABLE_SSM_AGENT=0
ENABLE_LYNIS=0

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

AMI="ami-0ac9fa195c3a98c56"
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

if [ $ENABLE_SSM_AGENT == 1 ]; then
  SSM_TAG=",{Key=ssm-installed,Value=true}"
else
  SSM_TAG=""
fi

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
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}${SSM_TAG}]" \
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

# Reasons To Install Packages
# audit - to enable /var/log/audit/audit.log.
# golang
# setools setroubleshoot - to debug selinux issues and needed by auditd.
# python libselinux-python3 - to support ansible
# udica - helps to generate selinux policies but I don't want it.

#
# How to remove all packages:
#   sudo rpm-ostree uninstall --all
# 

echo "Install packages one by one. More specific errors this way."
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install python libselinux-python3"

ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install audit"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install conntrack"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install ethtool"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install golang"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install make"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install openscap-scanner"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install scap-security-guide"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install setools"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install usbguard"
ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install zip"

#
# Installing setroubeshoot causes the following conflict:
#   Forbidden base package replacements:
#     libreport-filesystem 2.12.0-1.fc31 -> 2.13.1-3.fc31 (updates)
# ssh -t -i $PKI_PRIVATE_PEM $SSH_USER@$PUBLIC_IP "sudo rpm-ostree install setroubleshoot"

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

echo "run playbook."

GRUB_PASSWORD=$(cat grub-password.txt)

python3 $(which ansible-playbook) \
    -i inventory \
    --private-key $PKI_PRIVATE_PEM \
    -u $SSH_USER \
    playbook.main.yml

if [ $ENABLE_SSM_AGENT == 1 ]; then
  python3 $(which ansible-playbook) \
      --extra-vars "ssm_binary_dir=$SSM_BINARY_DIR" \
      -i inventory \
      --private-key $PKI_PRIVATE_PEM \
      -u $SSH_USER \
      playbook.aws-ssm-agent.yml
fi

if [ $ENABLE_CLOUDWATCH_AGENT == 1 ]; then
  python3 $(which ansible-playbook) \
      -i inventory \
      --private-key $PKI_PRIVATE_PEM \
      -u $SSH_USER \
      playbook.aws-cloudwatch-agent.yml
fi

if [ $ENABLE_LYNIS == 1 ]; then
  python3 $(which ansible-playbook) \
      --extra-vars "grub_password=$GRUB_PASSWORD" \
      -i inventory \
      --private-key $PKI_PRIVATE_PEM \
      -u $SSH_USER \
      playbook.lynis.confirmed.yml
fi

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
