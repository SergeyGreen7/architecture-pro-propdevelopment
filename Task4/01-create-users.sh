#!/bin/bash
set -euo pipefail

CONTEXT="${KUBE_CONTEXT:-minikube}"
CERT_DIR="${CERT_DIR:-$(dirname "$0")/certs}"
CLUSTER="$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CONTEXT\")].context.cluster}")"

mkdir -p "$CERT_DIR"

create_user() {
  local user="$1" group="$2" namespace="${3:-default}"

  openssl genrsa -out "$CERT_DIR/$user.key" 2048 2>/dev/null
  openssl req -new -key "$CERT_DIR/$user.key" -out "$CERT_DIR/$user.csr" -subj "/CN=$user/O=$group"

  kubectl --context "$CONTEXT" delete csr "$user" --ignore-not-found >/dev/null
  cat <<EOF | kubectl --context "$CONTEXT" apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $user
spec:
  request: $(base64 < "$CERT_DIR/$user.csr" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages: ["client auth"]
EOF
  kubectl --context "$CONTEXT" certificate approve "$user"

  for _ in $(seq 1 10); do
    cert="$(kubectl --context "$CONTEXT" get csr "$user" -o jsonpath='{.status.certificate}')"
    [ -n "$cert" ] && break
    sleep 1
  done
  echo "$cert" | base64 -d > "$CERT_DIR/$user.crt"

  kubectl config set-credentials "$user" \
    --client-certificate="$CERT_DIR/$user.crt" --client-key="$CERT_DIR/$user.key" --embed-certs=true
  kubectl config set-context "$user" --cluster="$CLUSTER" --user="$user" --namespace="$namespace"
  echo "Пользователь $user (группа $group) создан, контекст: $user"
}

# пользователь группа namespace по умолчанию
create_user "olga.viewer"    "viewers"
create_user "dmitry.dev"     "housing-devs"  "housing"
create_user "ivan.devops"    "devops"
create_user "anna.security"  "security"
