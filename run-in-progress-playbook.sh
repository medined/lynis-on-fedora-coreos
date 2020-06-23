#!/bin/bash

python3 \
  $(which ansible-playbook) \
  -i inventory \
  -u core \
  playbook.lynis-in-progress.yml
