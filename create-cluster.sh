#!/bin/bash
# this script stands up a k8s cluster using kind and installs metallb
# it is assumed you already have docker, kind, kubectl, and jq installed and in the $PATH
# it also assumes you have default docker networking which results in a /16 subnet


set -e # Stop and exit immediately if a command exits with a non-zero status.
#set -x # Show each command that is being run

export KUBECONFIG="${PWD}/kind.kubeconfig"

github_latest_release() {
  # function to retrieve the latest release version of a specified github repository
  # accepts 1 arguemnt, the combined username/repository name. i.e. 'user/repo'
  curl --silent "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}



# get latest metallb release
metallb_latest_release=$(github_latest_release "metallb/metallb")

# create kind cluster
kind create cluster --config=manifests/kind-config.yaml

# Install/configure metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${metallb_latest_release}/config/manifests/metallb-native.yaml
echo "Waiting for metallb to become ready..."
sleep 15
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# dynamically generated metallb config
export ipv4_subnet_first_two_octets=$(docker network inspect kind | jq -r '.[].IPAM.Config[0].Subnet' | awk -F "." '{ print $1"."$2  }')
cat manifests/metallb-config.tpl | envsubst > manifests/metallb-config.yaml
kubectl apply -f manifests/metallb-config.yaml


# install capsule multi-tenancy manager
kubectl apply -f https://raw.githubusercontent.com/clastix/capsule/master/config/install.yaml || true # always fails the first time due to cr and crd in same apply manifest
sleep 5 # wait for cr to initialize
kubectl apply -f https://raw.githubusercontent.com/clastix/capsule/master/config/install.yaml
sleep 5
kubectl wait --namespace capsule-system \
  --for=condition=ready pod \
  --selector=control-plane=controller-manager \
  --timeout=90s

echo "Your cluster is now ready. No tenants are created yet. It can take several minutes for the Capsule CRD to become ready. Consult the readme for further instructions."
