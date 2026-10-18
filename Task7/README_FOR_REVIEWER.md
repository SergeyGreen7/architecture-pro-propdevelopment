# Задание 7

- `01-create-namespace.yaml` — namespace `audit-zone` с PodSecurity `restricted`.
- `insecure-manifests/` — три пода с нарушениями: `privileged: true`, `hostPath`, запуск от root.
- `secure-manifests/` — те же поды, исправленные: не root, read-only файловая система, без `privileged` и `hostPath`. Образ `nginxinc/nginx-unprivileged`, потому что обычный `nginx` запускается от root.
- `gatekeeper/` — правила для `audit-zone`: запрет `privileged` и `hostPath`, обязательны `runAsNonRoot` и `readOnlyRootFilesystem`.
- `verify/` — скрипты проверки PodSecurity и Gatekeeper.
- `audit-policy.yaml` — пишет в audit log попытки создать под и изменения правил безопасности. Подключается как в задании 6.

## Запуск

```bash
kubectl apply -f 01-create-namespace.yaml
./verify/verify-admission.sh

kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.23.1/deploy/gatekeeper.yaml
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager

kubectl apply -f gatekeeper/constraint-templates/
kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate --all
kubectl apply -f gatekeeper/constraints/
./verify/validate-security.sh
```

## Проверка

- `verify-admission.sh`: три небезопасных пода отклонены PodSecurity, три исправленных проходят.
- `validate-security.sh`: исправленные поды проходят правила Gatekeeper, под без `readOnlyRootFilesystem` отклонён Gatekeeper.

PodSecurity срабатывает раньше Gatekeeper, поэтому небезопасные поды отклоняет он. Чтобы проверить сам Gatekeeper, используется под без `readOnlyRootFilesystem`: в `restricted` такого требования нет, и отклонить его может только Gatekeeper.
