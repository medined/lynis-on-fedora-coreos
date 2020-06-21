#!/bin/bash

ANSBILE_PLAYBOOK=$(which ansible-playbook)

# python3 \
#   $ANSBILE_PLAYBOOK \
#   -i inventory \
#   -u core \
#   playbook.lynis.executed.yml

python3 \
  $ANSBILE_PLAYBOOK \
  -i inventory \
  -u core \
  playbook.lynis.working.yml
