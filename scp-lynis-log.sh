#!/bin/bash

IP_ADDRESS=$(cat inventory | tail -n 1)
scp core@$IP_ADDRESS:/var/log/lynis.log .
