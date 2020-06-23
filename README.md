# Lynis on Fedora CoreOS

This project tries to pass every possible test that Lydis runs. If passing is not possible, it will document why.

This work is being done at the request of the Enterprise Container Working Group (ECWG) of the Office of Information and Technology (OIT - https://www.oit.va.gov/) at the Department of Veteran Affairs.

On 2020-Jun-23, a Lynis Hardening Index of 98 was acheived. This is as far as I will take the project for now.

Please read the **Skip Tests** section in `playbook-02-lynis-98.yml` to understand which tests were skipped and why.

Handy Note: A server is identified as `Fedora CoreOS` server using the ID=fedora and VARIANT_ID=coreos fields in the /etc/os-release file.

## Definitions

[**Fedora CoreOS**](https://getfedora.org/coreos), also known as FCOS, is an automatically-updating, minimal operating system for running containerized workloads securely and at scale. However, we’ll probably be replacing virtual servers instead of updating them. **The Fedora CoreOS ecosystem is very dynamic and anything in this document might change.**

[**Lynis**](https://cisofy.com/lynis/) is a battle-tested security tool for systems running Linux, macOS, or Unix-based operating system. It performs an extensive health scan of your systems to support system hardening and compliance testing. The project is open source software with the GPL license and available since 2007.

## Configuration

### external_vars.yml

This file holds variables used by the Ansible playbooks. They are externalized so they don't repeat in every playbook.

**For simplicity's sake, the ssh_port is not being used yet.**

The grub password is stored inside a file so that it won't be added to the code repository.

```yaml
---
ansible_python_interpreter: /usr/bin/python3
banner_text_file: file-banner-text.txt
grub_password_file: grub-password.txt
grub_user: core
password_max_days: 90
password_min_days: 1
sha_crypt_max_rounds: 10000
sha_crypt_min_rounds: 5000
ssh_port: 15762
```

## Generate GRUB Password

The grub boot loader should be password protected. This password is only needed by some physically at the server. Normal reboots are not affected. This is a manual process because I don't want to bury this information inside scripts. Password creation is important. The following command. Enter a password twice. Save the password somewhere in case you do need physical access to the server.

```bash
grub-mkpasswd-pbkdf2
PBKDF2 hash of your password is grub.pbkdf2.sha512.10000...042D445
```

Copy the part after "is " into a file called `grub_password.txt`. I've shortened the value to save space. If you use a different name, make sure to update `grub_password_file` in `external_vars.yml`.

### start-fcos-instance.sh

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

As you harden your instance, you can create an AMI to "save" your progress. If the AMI has a tag called `lynis-hardening-score` then many of the provisioning steps are avoided. Then run playbooks manually as needed.

## Provision FCOS Server

```bash
./start-fcos-instance.sh
./run-01-ostree-playbook.sh
./run-02-lynis-98-playbook.sh
```

The first script starts a new instance, installs python and then reboots.

The second script installs a bunch of packages including `lynis`. Even though the packages are installed using separate ansible tasks, they are all part of one layer from FCOS's perspective. After the packages are installed, the server reboots.

Now you can start to harden the server.

## SSH To Server

```bash
./ssh-to-server.sh
```

## Run Lynis

```bash
./run-lynis-audit-playbook.sh
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

## Links

* https://cisofy.com/lynis/
* https://github.com/CISOfy/lynis-ansible
