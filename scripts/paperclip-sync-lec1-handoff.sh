#!/usr/bin/env bash
# AI-GEN-BEGIN
# 解阻后：把 LEC-1 优化版同步到 Paperclip（评论 / plan / work product / 状态）。
# 依赖：PAPERCLIP_API_URL PAPERCLIP_API_KEY PAPERCLIP_COMPANY_ID PAPERCLIP_TASK_ID PAPERCLIP_RUN_ID PAPERCLIP_AGENT_ID
set -euo pipefail

: "${PAPERCLIP_API_URL:?missing PAPERCLIP_API_URL}"
: "${PAPERCLIP_API_KEY:?missing PAPERCLIP_API_KEY}"
: "${PAPERCLIP_COMPANY_ID:?missing PAPERCLIP_COMPANY_ID}"
: "${PAPERCLIP_TASK_ID:?missing PAPERCLIP_TASK_ID}"
: "${PAPERCLIP_RUN_ID:?missing PAPERCLIP_RUN_ID}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESIGN="$ROOT/docs/lec-1/optimized-login-management-design.md"
COMMENT="$ROOT/docs/lec-1/pending-final-comment.md"
WP_META="$ROOT/docs/lec-1/work-products.workspace.json"

python3 - <<PY
# AI-GEN-BEGIN
import json, os, urllib.request, urllib.error
from pathlib import Path

api = os.environ["PAPERCLIP_API_URL"].rstrip("/")
headers = {
    "Authorization": f"Bearer {os.environ['PAPERCLIP_API_KEY']}",
    "X-Paperclip-Run-Id": os.environ["PAPERCLIP_RUN_ID"],
    "X-Paperclip-Agent-Id": os.environ.get("PAPERCLIP_AGENT_ID", ""),
    "X-Paperclip-Company-Id": os.environ["PAPERCLIP_COMPANY_ID"],
    "Content-Type": "application/json",
    "Accept": "application/json",
}
task = os.environ["PAPERCLIP_TASK_ID"]
root = Path(r"""$ROOT""")


def call(method, path, body=None):
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
    req = urllib.request.Request(api + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code} {method} {path}: {e.read().decode()[:800]}") from e
    except urllib.error.URLError as e:
        raise SystemExit(f"URLError {method} {path}: {e}") from e


print("==> GET /api/agents/me")
print(call("GET", "/api/agents/me"))

comment = Path(r"""$COMMENT""").read_text(encoding="utf-8")
design = Path(r"""$DESIGN""").read_text(encoding="utf-8")

print("==> POST comment")
print(call("POST", f"/api/issues/{task}/comments", {"body": comment}))

print("==> PUT plan document")
try:
    print(call("PUT", f"/api/issues/{task}/documents/plan", {"title": "LEC-1 登录方案对比与优化版", "format": "markdown", "content": design}))
except SystemExit as e:
    print("plan put failed (non-fatal if endpoint differs):", e)

# work product: workspace_file fallback if upload script missing
wp = {
    "type": "document",
    "name": "LEC-1 优化版登录方案",
    "metadata": {
        "resourceRef": {
            "kind": "workspace_file",
            "path": "docs/lec-1/optimized-login-management-design.md"
        }
    }
}
print("==> POST work-products (best effort)")
try:
    print(call("POST", f"/api/issues/{task}/work-products", wp))
except SystemExit as e:
    print("work-product create failed (best effort):", e)

print("==> PATCH status blocked (awaiting child attachments + board review)")
print(call("PATCH", f"/api/issues/{task}", {
    "status": "blocked",
    "comment": "仓库侧优化版已就绪；等待控制面解阻后创建的方案 A/B 附件子任务，以及 board 确认 interim 输入。"
}))
print("OK")
# AI-GEN-END
PY
# AI-GEN-END
