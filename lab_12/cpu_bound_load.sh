#!/bin/bash

sleep 1

COUNTER=0
RESET_COUNTER=0

while true; do
    COUNTER=$((COUNTER+1))
    if [ $COUNTER -eq 250000 ]; then
        RESET_COUNTER=$((RESET_COUNTER+1))
        echo "$$ - CPU bound load counter $RESET_COUNTER"
        COUNTER=0
    fi
done
