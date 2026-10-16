# Задание 5

## Идея

В одном namespace работают четыре сервиса на nginx. Роль сервиса задаётся меткой `role`: `front-end`, `back-end-api`, `admin-front-end`, `admin-back-end-api`.

Весь входящий трафик к подам запрещён, разрешены только две пары, в обе стороны:

- `front-end` <-> `back-end-api`;
- `admin-front-end` <-> `admin-back-end-api`.

Всё остальное не проходит: обычный фронт не достучится до админского API, а посторонний под — ни до одного сервиса.

Политики лежат в `non-admin-api-allow.yaml`:

- `default-deny-ingress` — запрет всего входящего трафика;
- `allow-front-end-back-end-api` — первая пара;
- `allow-admin-front-end-admin-back-end-api` — вторая пара.

## Проверика

```bash
minikube start --cni=calico


```bash
kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80

kubectl apply -f non-admin-api-allow.yaml
```

Запустить тестовый под с меткой одного из сервисов и обратиться к остальным:

```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --labels role=front-end -- sh
/ # wget -qO- --timeout=2 http://back-end-api-app        # ответ nginx, трафик есть
/ # wget -qO- --timeout=2 http://admin-back-end-api-app  # download timed out, трафика нет
```

Для остальных строк таблицы меняем метку в `--labels` или убираем её.

Ожидаемый результат:

| Метка тестового пода | Доступен | Недоступны |
| --- | --- | --- |
| `front-end` | `back-end-api-app` | `admin-front-end-app`, `admin-back-end-api-app` |
| `back-end-api` | `front-end-app` | `admin-front-end-app`, `admin-back-end-api-app` |
| `admin-front-end` | `admin-back-end-api-app` | `front-end-app`, `back-end-api-app` |
| `admin-back-end-api` | `admin-front-end-app` | `front-end-app`, `back-end-api-app` |
| без метки | — | все четыре |
