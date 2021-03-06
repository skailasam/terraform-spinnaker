apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
- name: spinnaker-operator
  namespace: ${kubernetes_namespace}
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - endpoints
  - persistentvolumeclaims
  - events
  - configmaps
  - secrets
  - namespaces
  verbs:
  - '*'
- apiGroups:
  - batch
  - extensions
  resources:
  - jobs
  verbs:
  - '*'
- apiGroups:
  - apps
  - extensions
  resources:
  - deployments
  - daemonsets
  - replicasets
  - statefulsets
  verbs:
  - '*'
- apiGroups:
  - monitoring.coreos.com
  resources:
  - servicemonitors
  verbs:
  - get
  - create
- apiGroups:
  - apps
  resourceNames:
  - spinnaker-operator
  resources:
  - deployments/finalizers
  verbs:
  - update
- apiGroups:
  - spinnaker.io
  resources:
  - '*'
  - spinnakerservices
  verbs:
  - '*'