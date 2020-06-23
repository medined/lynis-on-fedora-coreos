#!/bin/bash

#
# This script runs the playbook that installs packages using
# rpm-ostree. After the packages are installed, the remote
# server needs to be rebooted which the playbook does.
#

python3 \
  $(which ansible-playbook) \
  -i inventory \
  -u core \
  playbook.01-ostree.yml

echo "The remote server is being rebooted. Wait a few minutes..."
