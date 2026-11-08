#!/bin/bash

F="${HOME}/.age/private-key.txt"

if [ ! -f "$F" ]; then
  echo "'$F' is not found."
  exit 1
fi

kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file=age.agekey="$F"
