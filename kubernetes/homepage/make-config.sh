#!/bin/sh
set -eu
[ -f homepage-config.yaml ] && rm homepage-config.yaml
kubectl create -n homepage \
  configmap homepage-config \
  --from-file=config/ \
  --dry-run=client \
  -o yaml | tee homepage-config.yaml
