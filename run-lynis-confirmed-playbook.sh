#!/bin/bash

ANSBILE_PLAYBOOK=$(which ansible-playbook)

# python3 \
#   $ANSBILE_PLAYBOOK \
#   -i inventory \
#   -u core \
#   playbook.lynis.executed.yml

if [ ! -f grub-password.txt ]; then
  echo "Missing grub-password.txt file."
  exit
fi

GRUB_PASSWORD=$(cat grub-password.txt)

python3 \
  $ANSBILE_PLAYBOOK \
  --extra-vars grub_password=$GRUB_PASSWORD \
  -i inventory \
  -u core \
  playbook.lynis.confirmed.yml
