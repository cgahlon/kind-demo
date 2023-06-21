#!/bin/bash
# This script stands up a k8s cluster using kind and installs metallb
# It is assumed you already have docker, kind, kubectl, and jq installed and in the $PATH
# It also assumes you have default networking which results in a /16


set -e # Stop and exit immediately if a command exits with a non-zero status.
#set -x # Show each command that is being run

github_latest_release() {
  # function to retrieve the latest release version of a specified github repository
  # accepts 1 arguemnt, the combined username/repository name. i.e. 'kind-kind'
  # example usage: github_latest_release 'kind-kind'
  curl --silent "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

metallb_latest_release=$(github_latest_release "metallb/metallb")

echo "Using metallb latest release: ${metallb_latest_release}"

# Create the cluster
kind create cluster --config=manifests/kind-config.yaml

# obtain IPV4 subnet
ipv4_subnet_first_two_octets=$(docker network inspect kind | jq -r '.[].IPAM.Config[0].Subnet' | awk -F "." '{ print $1"."$2  }')

echo "Docker network 'kind' IPV4 subnet first two octets are: ${ipv4_subnet_first_two_octets}"

# Uncomment the kubctl line to Install calico CNI
# IMPORTANT: You will need to set 'disableDefaultCNI: true' in the kind-config.yaml)
# Calico quickstart: https://docs.projectcalico.org/getting-started/kubernetes/quickstart
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Install/configure metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${metallb_latest_release}/config/manifests/metallb-native.yaml
echo "Waiting for metallb to become ready..."
sleep 15
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

cat <<EOF > manifests/metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - $ipv4_subnet_first_two_octets.255.200-$ipv4_subnet_first_two_octets.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
kubectl apply -f manifests/metallb-config.yaml
