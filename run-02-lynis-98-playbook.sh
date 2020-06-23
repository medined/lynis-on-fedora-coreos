#!/bin/bash

python3 \
  $(which ansible-playbook) \
  -i inventory \
  -u core \
  playbook.02-lynis-98.yml
