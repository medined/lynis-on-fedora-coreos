#!/bin/bash

#
# Use ssh-add to ensure your PEM file is accessible.
#
IP_ADDRESS=$(cat inventory | tail -n 1)
ssh core@$IP_ADDRESS
