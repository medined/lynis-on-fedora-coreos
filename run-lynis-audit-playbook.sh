#!/bin/bash

python3 \
  $(which ansible-playbook) \
  -i inventory \
  -u core \
  playbook.lynis.audit.yml

LYNIS_LOG=$(find /tmp/fetched -type f | xargs ls -ltr | tail -n 1 | awk '{print $NF}')

cp $LYNIS_LOG ./lynis.log

cat ./lynis.log
