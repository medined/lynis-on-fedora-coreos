#!/bin/bash

#
# Pay no attention to ths file.
#

ANSBILE_PLAYBOOK=$(which ansible-playbook)

python3 \
  $ANSBILE_PLAYBOOK \
  -i inventory \
  -u core \
  -vvvvv \
  playbook.experiment.yml
