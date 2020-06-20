# Lynis on Fedora CoreOS

This project tries to pass every possible test that Lydis runs. If passing is not possible, it will document why.

This work is being done at the request of the Enterprise Container Working Group (ECWG) of the Office of Information and Technology (OIT - https://www.oit.va.gov/) at the Department of Veteran Affairs.

## Goal

* Provision an EC2 instance based on a Fedora CoreOS AMI. The instance name will be timestamped so you can make more than one.
* Pass as many Lydis tests as possible.

## Definitions

[**Fedora CoreOS**](https://getfedora.org/coreos), also known as FCOS, is an automatically-updating, minimal operating system for running containerized workloads securely and at scale. However, we’ll probably be replacing virtual servers instead of updating them. **The Fedora CoreOS ecosystem is very dynamic and anything in this document might change.**

[**Lynis**](https://cisofy.com/lynis/) is a battle-tested security tool for systems running Linux, macOS, or Unix-based operating system. It performs an extensive health scan of your systems to support system hardening and compliance testing. The project is open source software with the GPL license and available since 2007.

## Configuration

Edit the `start-fcos-instance.sh` file to set the following variables.

| Name | Example | Description |
| ---- | ------- | ----------- |
| AMI | ami-0ac9fa195c3a98c56 | Get this value from [Fedora Releases](https://getfedora.org/en/coreos/download?tab=cloud_launchable&stream=stable).|
| AWS_PROFILE | default | Setup your credentials in `~/.aws/credentials`.
| AWS_REGION | us-east-1 |
| IGNITION_FILE_BASE | lydis | The base name of the ignition file. Not really important. |
| INSTANCE_TYPE | t3.medium | This is probably the smallest instace you should use. |
| KEY_NAME | fcos | The name of an EC2 key pair. |
| SECURITY_GROUP_ID | sg-0a4ad278f69b3d617 | A security group allowing SSH access to the EC2 instance. |
| SUBNET_ID | subnet-02c78f939d58e2320 | A public subnet |
| PKI_PRIVATE_PEM | PRIVATE_KEY.pem |
| PKI_PUBLIC_PUB | PUBLIC_KEY.pub |
| SSM_BINARY_DIR | amazon-ssm-agent/bin | The location of  binaries associated with the Amazon SSM Agent |

## Provision FCOS Server

```bash
./start-fcos-instance.sh
```

# Backup Information

## Getting Amazon SSM Agent

I compiled the binaries from the GitHub project at https://github.com/aws/amazon-ssm-agent. If you want a pre-compiled binary, try https://github.com/medined/aws-ssm-agent-for-fedora-coreos. 

## Why Use /data/pem Instead of ~/.ssh?

* It is possible to have too many keys in the `~/.ssh` directory. 
* For each SSH access, each keys in `~/.ssh` will be tried.

## How To Create PKI Public Key From Private Key

Use the following command as a guide.

```bash
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
```
