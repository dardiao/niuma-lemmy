#!/usr/bin/env bash
# 新实例初始化：站点名、申请问题、语言、管理员显示名，并上传站点图标。
# 前提：实例已经建好管理员（用建站向导，或 .env 里的 ADMIN_PASSWORD 自动建站）。
# 可重复执行。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$HERE/.env}"
ICON_FILE="${ICON_FILE:-$HERE/../lemmy-ui/src/assets/icons/icon-512x512.png}"

if [ ! -f "$ENV_FILE" ]; then
  echo "缺少 $ENV_FILE" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

: "${LEMMY_DOMAIN:?请在 .env 里设置 LEMMY_DOMAIN}"
ADMIN_USERNAME="${ADMIN_USERNAME:-niuma}"
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  read -r -s -p "输入管理员 ${ADMIN_USERNAME} 的密码: " ADMIN_PASSWORD
  echo
fi
BASE="https://${LEMMY_DOMAIN}"

echo "等待 ${BASE} 可用…"
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "$BASE/api/v3/site"; then break; fi
  sleep 5
done
if ! curl -fsS -o /dev/null "$BASE/api/v3/site"; then
  echo "站点还没起来，先确认容器状态和证书" >&2
  exit 1
fi

echo "登录管理员…"
JWT="$(curl -fsS -X POST "$BASE/api/v3/user/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username_or_email\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" |
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("jwt",""))')"
if [ -z "$JWT" ]; then
  echo "登录失败：检查用户名/密码" >&2
  exit 1
fi

api() {
  curl -fsS -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' "$@"
}

# 语言表由迁移写入，中文的 id 从接口里查，不写死
ZH_ID="$(api "$BASE/api/v3/site" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(next((l["id"] for l in d["all_languages"] if l["name"] == "中文"), ""))')"
if [ -n "$ZH_ID" ]; then
  echo "语言：未确定 + 中文 (id ${ZH_ID})"
else
  echo "没找到中文语言项，跳过语言设置" >&2
fi

echo "设置站点信息…"
SITE_BODY="$(python3 - "$ZH_ID" <<'PY'
import json,sys
zh=sys.argv[1]
body={
  "name": "牛马俱乐部",
  "application_question": "请简单说明你注册本站的用途，以及你在 HapDNS 注册的子域名。",
}
if zh:
    body["discussion_languages"]=[0,int(zh)]
print(json.dumps(body, ensure_ascii=False))
PY
)"
api -X PUT "$BASE/api/v4/site" -d "$SITE_BODY" > /dev/null

echo "设置管理员显示名…"
USER_BODY="$(python3 - "$ZH_ID" <<'PY'
import json,sys
zh=sys.argv[1]
body={"display_name":"牛马站长"}
if zh:
    body["discussion_languages"]=[0,int(zh)]
print(json.dumps(body, ensure_ascii=False))
PY
)"
api -X PUT "$BASE/api/v4/account/settings/save" -d "$USER_BODY" > /dev/null

if [ -f "$ICON_FILE" ]; then
  echo "上传站点图标…"
  api -X POST "$BASE/api/v4/site/icon" \
    -H 'Content-Type: image/png' --data-binary "@$ICON_FILE" > /dev/null
else
  echo "未找到图标文件 $ICON_FILE，跳过（可在后台「站点 → 图标」手工上传）"
fi

echo
echo "完成，当前状态："
curl -fsS "$BASE/api/v3/site" | python3 -c '
import json,sys
d=json.load(sys.stdin)
s=d["site_view"]["site"]
print("  站点名:", s["name"])
print("  站点图标:", s.get("icon") or "(未设置)")
print("  语言数:", len(d.get("discussion_languages") or []))
print("  管理员:", d["admins"][0]["person"]["name"], "/", d["admins"][0]["person"].get("display_name"))
'
