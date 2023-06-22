---
#
# WARNING: This file is dynamically generated. Do not edit.
#
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - ${ipv4_subnet_first_two_octets}.255.200-${ipv4_subnet_first_two_octets}.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
