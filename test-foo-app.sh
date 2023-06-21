#!/usr/bin/env bash

set -e # stop immediately on error

LB_IP=$(kubectl get svc/foo-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Testing ingress IP address: ${LB_IP}"
# should output foo and bar on separate lines
for _ in {1..10}; do
  curl ${LB_IP}:5678
done
