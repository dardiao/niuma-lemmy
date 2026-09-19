#!/usr/bin/env bash
# 读取 .env，生成 lemmy 的生产配置文件（lemmy.prod.hjson）。
# 缺的密码会自动生成并写回 .env，所以可以重复执行。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/.env"
OUT_FILE="$HERE/lemmy.prod.hjson"

if [ ! -f "$ENV_FILE" ]; then
  echo "缺少 $ENV_FILE，先执行： cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

random_secret() {
  # 用 openssl 而不是 `tr | head`：后者在 set -o pipefail 下会因 SIGPIPE 直接失败
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 || true
  fi
}

# 把某个变量写回 .env（不存在就追加，存在就替换），避免重复执行时反复生成
set_env_var() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  if grep -q "^${key}=" "$ENV_FILE"; then
    awk -v k="$key" -v v="$value" \
      'BEGIN{FS=OFS="="} $1==k {print k"="v; next} {print}' "$ENV_FILE" > "$tmp"
  else
    cp "$ENV_FILE" "$tmp"
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi
  mv "$tmp" "$ENV_FILE"
}

if [ -z "${POSTGRES_PASSWORD:-}" ]; then
  POSTGRES_PASSWORD="$(random_secret)"
  set_env_var POSTGRES_PASSWORD "$POSTGRES_PASSWORD"
  echo "已生成 POSTGRES_PASSWORD 并写回 .env"
fi

if [ -z "${PICTRS_API_KEY:-}" ]; then
  PICTRS_API_KEY="$(random_secret)"
  set_env_var PICTRS_API_KEY "$PICTRS_API_KEY"
  echo "已生成 PICTRS_API_KEY 并写回 .env"
fi

if [ -z "${LEMMY_DOMAIN:-}" ] || [ -z "${ACME_EMAIL:-}" ] ||
  [ "${ACME_EMAIL}" = "you@example.com" ]; then
  echo "提醒：LEMMY_DOMAIN / ACME_EMAIL 还没填全，确认一下 .env" >&2
fi

{
  echo "{"
  echo "  # 由 write-config.sh 生成，不要手工改（改 .env 后重新执行本脚本）"
  echo "  database: {"
  echo "    connection: \"postgres://lemmy:${POSTGRES_PASSWORD}@postgres:5432/lemmy\""
  echo "  }"
  echo
  echo "  # 站点身份：决定 ActivityPub 的 ap_id，必须在首次建站前定好，之后不能改"
  echo "  hostname: \"${LEMMY_DOMAIN}\""
  echo "  bind: \"0.0.0.0\""
  echo "  port: 8536"
  echo
  echo "  pictrs: {"
  echo "    url: \"http://pictrs:8080/\""
  echo "    api_key: \"${PICTRS_API_KEY}\""
  echo "  }"

  # 这版 Lemmy 的邮件配置是单个 lettre 连接串（smtp:// 或 smtps://），
  # 用户名和密码会被百分号解码，所以 QQ 邮箱里的 @ 要写成 %40。
  if [ -n "${SMTP_HOST:-}" ] && [ -n "${SMTP_PASSWORD:-}" ]; then
    urlenc() {
      python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
    }
    SMTP_PORT="${SMTP_PORT:-465}"
    if [ "${SMTP_TLS:-smtps}" = "starttls" ]; then
      CONN="smtp://$(urlenc "${SMTP_LOGIN}"):$(urlenc "${SMTP_PASSWORD}")@${SMTP_HOST}:${SMTP_PORT}?tls=required"
    else
      CONN="smtps://$(urlenc "${SMTP_LOGIN}"):$(urlenc "${SMTP_PASSWORD}")@${SMTP_HOST}:${SMTP_PORT}"
    fi
    echo
    echo "  email: {"
    echo "    connection: \"${CONN}\""
    echo "    smtp_from_address: \"${SMTP_FROM:-$SMTP_LOGIN}\""
    echo "  }"
  else
    echo "提醒：未配置 SMTP，用户将无法重置密码、注册申请也不会有邮件通知" >&2
  fi

  # 只在显式提供了初始管理员密码时才写 setup 块；否则用网页建站向导
  if [ -n "${ADMIN_PASSWORD:-}" ]; then
    echo
    echo "  setup: {"
    echo "    admin_username: \"${ADMIN_USERNAME:-niuma}\""
    echo "    admin_password: \"${ADMIN_PASSWORD}\""
    echo "    site_name: \"${SITE_NAME:-牛马俱乐部}\""
    echo "  }"
  fi

  echo "}"
} > "$OUT_FILE"

chmod 600 "$OUT_FILE"
echo "已生成 $OUT_FILE"
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  echo "未设置 ADMIN_PASSWORD：首次启动后请在浏览器里用建站向导创建管理员。"
fi
