#!/bin/bash

python3 \
  $(which ansible-playbook) \
  -i inventory \
  -u core \
  playbook.lynis.audit.yml


echo "Lynis Log File"
echo "--------------"
find /tmp/fetched -type f | xargs ls -ltr | tail -n 1
