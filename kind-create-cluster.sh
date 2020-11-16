#!/bin/bash
# This script stands up a k8s cluster using kind and intalls metallb
#
set -e # Stop and exit immediately if a command exits with a non-zero status.
set -x # Show each command that is being run

# Create the cluster
kind create cluster --config=kind-config.yaml

# Uncomment these two lines to Install calico CNI
# NOTE: You will need to set 'disableDefaultCNI: true' in the kind-config.yaml)
# Calico quickstart: https://docs.projectcalico.org/getting-started/kubernetes/quickstart
# kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
# or for latest use this:
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Install/configure metallb v0.9.3
# FROM: https://metallb.universe.tf/installation/
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
# Create the metallb configmap for protocol and range of IPs to use
kubectl create -f metallb.yaml
# Install metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
# Run once on first install of metallb.
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

