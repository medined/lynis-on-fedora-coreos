#!/bin/bash

HOST=$1
PEM=$2
USER=$3
PORT=22
#HOST="localhost"
#PORT=8022
if [ -z "$1" ]
  then
    echo "Missing argument for host."
    exit 1 
fi

echo "polling to see that host is up and ready"
RESULT=1 # 0 upon success
TIMEOUT=30 # number of iterations (5 minutes?)
while :; do 
    echo "waiting for server ping ..."
    status=$(ssh -i ${PEM} -o BatchMode=yes -o ConnectTimeout=5 ${USER}@${HOST} -p ${PORT} echo ok 2>&1)
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        # this is not really expected unless a key lets you log in
        echo "connected ok"
        break
    fi
    if [ $RESULT -eq 255 ]; then
        # connection refused also gets you here
        if [[ $status == *"Permission denied"* ]] ; then
            # permission denied indicates the ssh link is okay
            echo "server response found"
            break
        fi
    fi
    TIMEOUT=$((TIMEOUT-1))
    if [ $TIMEOUT -eq 0 ]; then
        echo "timed out"
        # error for jenkins to see
        exit 1 
    fi
    sleep 10
done
