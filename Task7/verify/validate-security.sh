#!/bin/bash
# Проверка OPA Gatekeeper: правила установлены и применяются в audit-zone
cd "$(dirname "$0")/.." || exit 1

fail=0

kubectl -n gatekeeper-system get pods
echo
kubectl get constraints
echo

for f in secure-manifests/*.yaml; do
  if out=$(kubectl apply --dry-run=server -f "$f" 2>&1); then
    echo "OK    $f проходит правила Gatekeeper"
  else
    echo "FAIL  $f: $out"
    fail=1
  fi
done

# под проходит PodSecurity restricted, но без readOnlyRootFilesystem, отклонить его может только Gatekeeper
out=$(kubectl apply --dry-run=server -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-readonly-fs
  namespace: audit-zone
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: nginx
      image: nginxinc/nginx-unprivileged:alpine
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
EOF
)
if echo "$out" | grep -q 'validation.gatekeeper.sh'; then
  echo "OK    под без readOnlyRootFilesystem отклонён Gatekeeper"
  echo "      ${out#*denied the request: }"
else
  echo "FAIL  под без readOnlyRootFilesystem: $out"
  fail=1
fi

exit $fail
