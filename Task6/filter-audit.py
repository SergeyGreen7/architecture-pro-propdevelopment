#!/usr/bin/env python3
# Запуск: python3 filter-audit.py [audit.log] [audit-extract.json]
import json
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "audit.log"
dst = sys.argv[2] if len(sys.argv) > 2 else "audit-extract.json"

# служебные учётки кластера и установки (kubeadm, minikube), их действия не смотрим
SYSTEM = ("system:apiserver", "system:kube-", "system:node:", "system:serviceaccount:kube-system:")
INSTALL = ("kubernetes-admin", "kubernetes-super-admin", "minikube")


def is_privileged(e):
    spec = (e.get("requestObject") or {}).get("spec") or {}
    return any((c.get("securityContext") or {}).get("privileged") for c in spec.get("containers", []))


def why(e):
    ref = e.get("objectRef") or {}
    res, sub, name, verb = ref.get("resource"), ref.get("subresource"), ref.get("name"), e["verb"]
    if res == "secrets" and verb in ("get", "list"):
        return "доступ к секретам"
    if res == "pods" and not sub and verb == "create" and is_privileged(e):
        return "привилегированный под"
    if res == "pods" and sub == "exec":
        return "exec в под"
    if res in ("rolebindings", "clusterrolebindings") and verb in ("create", "update", "patch"):
        return "выдача прав"
    if name == "audit-policy" and verb in ("create", "update", "patch", "delete"):
        return "изменение audit-policy"
    if ref and e.get("impersonatedUser"):
        return "действие от чужого имени"
    return None


found = []
with open(src) as f:
    for line in f:
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            # лог копируется на ходу, последняя строка может быть недописана
            continue
        user = e["user"]["username"]
        if e["stage"] != "ResponseComplete" or user.startswith(SYSTEM) or user in INSTALL:
            continue
        reason = why(e)
        if not reason:
            continue

        ref = e.get("objectRef") or {}
        if ref.get("resource") == "secrets":
            # значения секретов не должны попасть в выжимку
            e.pop("requestObject", None)
            e.pop("responseObject", None)
        found.append(e)

        as_user = (e.get("impersonatedUser") or {}).get("username")
        who = f"{user} as {as_user}" if as_user else user
        obj = "/".join(x for x in (ref.get("namespace"), ref.get("resource"), ref.get("name"), ref.get("subresource")) if x)
        print(f'{e["requestReceivedTimestamp"][11:19]} | {reason} | {who} | {e["verb"]} {obj} | {e["responseStatus"]["code"]}')

with open(dst, "w") as f:
    json.dump(found, f, ensure_ascii=False, indent=2)
print(f"\nНайдено событий: {len(found)}, сохранено в {dst}")
