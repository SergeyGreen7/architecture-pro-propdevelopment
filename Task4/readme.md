# Задание 4. Защита доступа к кластеру Kubernetes

## Роли

| Роль  | Права роли | Группы пользователей |
| --- | --- | --- |
| `cluster-viewer` | Только просмотр ресурсов кластера, без secrets и логов | `viewers` — владельцы продуктов, аналитики |
| `domain-developer` | Управление приложениями в namespace своего домена, без secrets | `sales-devs`, `housing-devs`, `finance-devs`, `data-devs`, `smart-home-devs` — разработчики доменов |
| `cluster-operator` | Настройка кластера: namespaces, nodes, квоты, хранилища, сеть. Без secrets и RBAC | `devops` — DevOps-инженеры |
| `security-auditor` | Привилегированная: просмотр всего, включая secrets. Изменять ничего не может | `security` — специалист по ИБ |
| `cluster-admin` (встроенная) | Полный доступ, только для аварийных работ | `cluster-admins` — ведущие инженеры платформы |

Namespace по доменам: `sales`, `housing`, `finance`, `data`, `smart-home`.

## Скрипты

```bash
minikube start
./01-create-users.sh
./02-create-roles.sh
./03-bind-roles.sh
```

## Проверка

```bash
kubectl --context olga.viewer get secrets -A                       # Forbidden
kubectl --context dmitry.dev create deployment test --image=nginx  # можно
kubectl --context ivan.devops auth can-i create namespaces         # yes
kubectl --context anna.security get secrets -A                     # можно
```
