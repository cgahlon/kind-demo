#!/usr/bin/env bash

# (re)make a tmp dir to store user specific files and secrets
rm -rf tmp > /dev/null 2>&1 || true
mkdir tmp

# create namespace and role for developers
kubectl apply -f manifests/developer-namespace.yaml
kubectl apply -f manifests/developer-role.yaml

# user create loop
for i in {1..2};do  # increase range to create more users
# generate user keys
openssl genrsa -out tmp/user${i}.key 2048

# create a certificate signing request
openssl req -new -key tmp/user${i}.key -out tmp/user${i}.csr -subj "/CN=foo/O=bar"

# encode certificates
users_base64_csr=$(cat tmp/user${i}.csr | base64 | tr -d '\n')


# create user certificates and generate kubeconfigs
cat <<EOF > tmp/user${i}-sign-cert.yaml
---
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: user${i}
spec:
  signerName:
  groups:
  - system:authenticated
  request: ${users_base64_csr}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

kubectl apply -f tmp/user${i}-sign-cert.yaml
kubectl certificate approve user${i}

export USER=user${i}
export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.current-context}')
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr user${i} -o jsonpath='{.status.certificate}')
export CLUSTER_CA=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')
export CLUSTER_ENDPOINT=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."server"')
cat manifests/kubeconfig.tpl | envsubst > tmp/kubeconfig-user${i}.yaml
KUBECONFIG=tmp/kubeconfig-user${i}.yaml kubectl config set-credentials user${i} --client-key=tmp/user${i}.key --embed-certs=true

cat << EOF > tmp/role-binding-user${i}.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: dev
 namespace: development
subjects:
- kind: User
  name: user${i}
  apiGroup: rbac.authorization.k8s.io
roleRef:
 kind: Role
 name: dev
 apiGroup: rbac.authorization.k8s.io
EOF

done
