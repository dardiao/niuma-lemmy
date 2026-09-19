#!/usr/bin/env bash
# 部署后验收。用法：./health-check.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$HERE/.env}"
COMPOSE_DIR="${COMPOSE_DIR:-$HERE/../lemmy/docker}"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

BASE="https://${LEMMY_DOMAIN}"
ADMIN="${ADMIN_USERNAME:-niuma}"
FAILED=0

ok() { printf '  ✅ %s\n' "$1"; }
bad() {
  printf '  ❌ %s\n' "$1"
  FAILED=$((FAILED + 1))
}

echo "1. 容器状态"
UNHEALTHY="$(docker compose --env-file "$ENV_FILE" \
  -f "$COMPOSE_DIR/docker-compose.yml" -f "$COMPOSE_DIR/docker-compose.prod.yml" \
  ps --format '{{.Name}} {{.Status}}' | grep -v '(healthy)' || true)"
if [ -z "$UNHEALTHY" ]; then ok "全部容器 healthy"; else bad "有容器不健康：$UNHEALTHY"; fi

echo "2. 对外端口"
for port in 80 443; do
  if curl -sS -o /dev/null --max-time 5 "http://127.0.0.1:$port" 2>/dev/null ||
    curl -sS -o /dev/null --max-time 5 -k "https://127.0.0.1:$port" 2>/dev/null; then
    ok "端口 $port 有服务"
  else
    bad "端口 $port 没响应"
  fi
done
if nc -z -w 3 "$LEMMY_DOMAIN" 5433 2>/dev/null; then
  bad "5433（数据库）能从公网连上，必须关掉"
else
  ok "数据库端口未暴露"
fi

echo "3. HTTP 跳转到 HTTPS"
CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "http://${LEMMY_DOMAIN}/" || true)"
case "$CODE" in
30[0-9]) ok "http → https ($CODE)" ;;
*) bad "http 没有跳转（返回 $CODE）" ;;
esac

echo "4. 站点与 API"
if curl -fsS -o /tmp/hc-site.json --max-time 15 "$BASE/api/v3/site"; then
  ok "API 可访问"
  python3 - <<'PY'
import json
d = json.load(open("/tmp/hc-site.json"))
print("     站点名:", d["site_view"]["site"]["name"])
print("     语言数:", len(d.get("discussion_languages") or []))
print("     管理员:", d["admins"][0]["person"]["name"], "/",
      d["admins"][0]["person"].get("display_name"))
PY
else
  bad "API 打不开"
fi
curl -fsS -o /dev/null --max-time 15 "$BASE/" && ok "首页可访问" || bad "首页打不开"

echo "5. 注册页的子域名校验（需要 UI 容器能访问 hapdns.com）"
if curl -fsS --max-time 15 "$BASE/domain-check?name=api" | grep -q '"registered"'; then
  ok "校验接口返回「已注册」"
else
  bad "校验接口异常或出网失败"
fi
curl -fsS --max-time 15 "$BASE/domain-check?name=definitely-not-registered-xyz" |
  grep -q '"unregistered"' && ok "未注册的域名被正确识别" || bad "未注册判断异常"

echo "6. 联邦发现接口"
if curl -fsS -o /dev/null --max-time 15 \
  "$BASE/.well-known/webfinger?resource=acct:${ADMIN}@${LEMMY_DOMAIN}"; then
  ok "webfinger 正常（其它实例能找到你）"
else
  bad "webfinger 打不开，联邦会失败"
fi
# nodeinfo 的实际地址由发现文档给出（这版是 /nodeinfo/2.1），不要写死版本号
NODEINFO_URL="$(curl -fsS --max-time 15 "$BASE/.well-known/nodeinfo" 2>/dev/null |
  python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d["links"][0]["href"])
except Exception:
    print("")' 2>/dev/null)"
if [ -n "$NODEINFO_URL" ] && curl -fsS -o /dev/null --max-time 15 "$NODEINFO_URL"; then
  ok "nodeinfo 正常（$NODEINFO_URL）"
else
  bad "nodeinfo 打不开或发现文档异常"
fi

echo
if [ "$FAILED" = "0" ]; then
  echo "验收通过 ✅"
  exit 0
fi
echo "有 $FAILED 项没通过 ❌"
exit 1
