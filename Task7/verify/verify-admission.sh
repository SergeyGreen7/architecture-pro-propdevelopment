#!/bin/bash
# Проверка PodSecurity Admission в namespace audit-zone
cd "$(dirname "$0")/.." || exit 1

fail=0

echo "Метки audit-zone: $(kubectl get ns audit-zone -o jsonpath='{.metadata.labels}')"
echo

for f in insecure-manifests/*.yaml; do
  out=$(kubectl apply --dry-run=server -f "$f" 2>&1)
  if echo "$out" | grep -q 'violates PodSecurity'; then
    echo "OK    $f отклонён"
    echo "      ${out#*violates }"
  else
    echo "FAIL  $f: $out"
    fail=1
  fi
done

for f in secure-manifests/*.yaml; do
  if out=$(kubectl apply --dry-run=server -f "$f" 2>&1); then
    echo "OK    $f проходит"
  else
    echo "FAIL  $f: $out"
    fail=1
  fi
done

exit $fail
