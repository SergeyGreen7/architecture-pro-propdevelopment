#!/bin/bash
set -euo pipefail

CONTEXT="${KUBE_CONTEXT:-minikube}"

for ns in sales housing finance data smart-home; do
  kubectl --context "$CONTEXT" create namespace "$ns" --dry-run=client -o yaml \
    | kubectl --context "$CONTEXT" apply -f -
  kubectl --context "$CONTEXT" label namespace "$ns" domain="$ns" --overwrite
done

cat <<'EOF' | kubectl --context "$CONTEXT" apply -f -
# Только просмотр ресурсов во всём кластере. Нет secrets и логов подов (в логах могут быть ПДн).
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "configmaps", "events", "namespaces", "nodes",
                "persistentvolumes", "persistentvolumeclaims", "resourcequotas", "limitranges"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
---
# Работа с приложениями своей команды.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: domain-developer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/log", "events"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "deployments/scale", "statefulsets", "statefulsets/scale", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Настройка кластера: namespace, узлы, сеть, хранилища, квоты, приложения во всех namespace.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-operator
rules:
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "pods", "services", "endpoints", "configmaps", "serviceaccounts",
                "persistentvolumes", "persistentvolumeclaims", "resourcequotas", "limitranges"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/log", "events"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch", "autoscaling", "policy"]
    resources: ["*"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "ingressclasses", "networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Привилегированная роль ИБ: читает всё, включая secrets и RBAC, но ничего не меняет.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
EOF
