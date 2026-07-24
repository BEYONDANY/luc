#!/usr/bin/env bash
# AI-GEN-BEGIN
# 在 LEC-1 下创建两个「方案附件」子任务，并把父任务设为 blocked。
# 依赖心跳注入：PAPERCLIP_API_URL / PAPERCLIP_API_KEY / PAPERCLIP_COMPANY_ID /
# PAPERCLIP_TASK_ID / PAPERCLIP_RUN_ID。
set -euo pipefail

export PAPERCLIP_API_URL PAPERCLIP_API_KEY PAPERCLIP_COMPANY_ID PAPERCLIP_TASK_ID PAPERCLIP_RUN_ID

: "${PAPERCLIP_API_URL:?missing PAPERCLIP_API_URL}"
: "${PAPERCLIP_API_KEY:?missing PAPERCLIP_API_KEY — cursor_cloud 需注入 run JWT}"
: "${PAPERCLIP_COMPANY_ID:?missing PAPERCLIP_COMPANY_ID}"
: "${PAPERCLIP_TASK_ID:?missing PAPERCLIP_TASK_ID}"
: "${PAPERCLIP_RUN_ID:?missing PAPERCLIP_RUN_ID}"

python3 - <<'PY'
# AI-GEN-BEGIN
import json
import os
import urllib.error
import urllib.request

api = os.environ["PAPERCLIP_API_URL"].rstrip("/")
headers = {
    "Authorization": f"Bearer {os.environ['PAPERCLIP_API_KEY']}",
    "X-Paperclip-Run-Id": os.environ["PAPERCLIP_RUN_ID"],
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def call(method: str, path: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(api + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {e.code} {method} {path}: {detail[:800]}") from e
    except urllib.error.URLError as e:
        raise SystemExit(
            f"URLError {method} {path}: {e} "
            f"(检查 PAPERCLIP_API_URL 是否对 Cloud agent 可达，且不是运营侧 loopback)"
        ) from e


print("==> probe GET /api/agents/me")
me = call("GET", "/api/agents/me")
print(f"agent={me.get('id') or me.get('agent', {}).get('id')} company={me.get('companyId')}")

print("==> fetch parent heartbeat-context for goalId")
ctx = call("GET", f"/api/issues/{os.environ['PAPERCLIP_TASK_ID']}/heartbeat-context")
goal = ctx.get("goal") or ctx.get("goalSummary") or {}
goal_id = goal.get("id") or ""
print(f"goalId={goal_id or '<none>'}")

desc_a = (
    "请在本子任务上传「方案 A」相关文件/文档（可多附件）。\n\n"
    "完成后将本子任务标为 done。父任务 LEC-1 将在两个方案附件都就绪后，"
    "分析差异与优缺点并整理综合方案。\n\n"
    "建议附件内容：架构说明、关键流程、技术选型、优缺点自评、相关原型或代码片段索引。"
)
desc_b = (
    "请在本子任务上传「方案 B」相关文件/文档（可多附件）。\n\n"
    "完成后将本子任务标为 done。父任务 LEC-1 将在两个方案附件都就绪后，"
    "分析差异与优缺点并整理综合方案。\n\n"
    "建议附件内容：架构说明、关键流程、技术选型、优缺点自评、相关原型或代码片段索引。"
)


def create_child(title: str, description: str) -> dict:
    body = {
        "title": title,
        "description": description,
        "status": "todo",
        "priority": "medium",
        "parentId": os.environ["PAPERCLIP_TASK_ID"],
    }
    if goal_id:
        body["goalId"] = goal_id
    return call("POST", f"/api/companies/{os.environ['PAPERCLIP_COMPANY_ID']}/issues", body)


print("==> create child A")
child_a = create_child("LEC-1 子任务：提交方案 A 附件", desc_a)
print(f"A id={child_a.get('id')} identifier={child_a.get('identifier')}")

print("==> create child B")
child_b = create_child("LEC-1 子任务：提交方案 B 附件", desc_b)
print(f"B id={child_b.get('id')} identifier={child_b.get('identifier')}")

ident_a = child_a.get("identifier") or child_a["id"]
ident_b = child_b.get("identifier") or child_b["id"]
comment = (
    "已创建 2 个附件收集子任务，等待人工提交方案文件：\n\n"
    f"- 方案 A：{ident_a}\n"
    f"- 方案 B：{ident_b}\n\n"
    "请在各子任务上传对应方案附件并标 done。"
    "两子任务都完成后，父任务将因 blockers 解除被重新唤醒，"
    "再进行差异/优缺点分析并整理综合方案。"
)

print("==> patch parent to blocked by children")
patched = call(
    "PATCH",
    f"/api/issues/{os.environ['PAPERCLIP_TASK_ID']}",
    {
        "status": "blocked",
        "blockedByIssueIds": [child_a["id"], child_b["id"]],
        "comment": comment,
    },
)
print(f"parent status={patched.get('status')} blockers={patched.get('blockedByIssueIds')}")
print(f"OK children={ident_a},{ident_b}")
# AI-GEN-END
PY
# AI-GEN-END
