#!/bin/bash
set -euo pipefail

CONTEXT="${KUBE_CONTEXT:-minikube}"

bind_cluster_role() {
  local group="$1" role="$2"
  kubectl --context "$CONTEXT" create clusterrolebinding "$group-$role" \
    --clusterrole="$role" --group="$group" --dry-run=client -o yaml \
    | kubectl --context "$CONTEXT" apply -f -
}

bind_cluster_role "viewers"         "cluster-viewer"
bind_cluster_role "devops"          "cluster-operator"
bind_cluster_role "security"        "security-auditor"
bind_cluster_role "cluster-admins"  "cluster-admin"

for ns in sales housing finance data smart-home; do
  kubectl --context "$CONTEXT" create rolebinding "$ns-devs-domain-developer" \
    --clusterrole="domain-developer" --group="$ns-devs" --namespace="$ns" --dry-run=client -o yaml \
    | kubectl --context "$CONTEXT" apply -f -
done
