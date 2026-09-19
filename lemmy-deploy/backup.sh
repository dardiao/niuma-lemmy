#!/usr/bin/env bash
# 备份 Lemmy 数据库 + 图片，保留 N 天。建议放进 cron 每天跑：
#   0 4 * * * /home/you/lemmy-deploy/backup.sh >> /var/log/lemmy-backup.log 2>&1
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$HERE/.env}"
COMPOSE_DIR="${COMPOSE_DIR:-$HERE/../lemmy/docker}"
BACKUP_DIR="${BACKUP_DIR:-$HERE/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M%S)"

compose() {
  docker compose --env-file "$ENV_FILE" \
    -f "$COMPOSE_DIR/docker-compose.yml" \
    -f "$COMPOSE_DIR/docker-compose.prod.yml" "$@"
}

mkdir -p "$BACKUP_DIR"
echo "[$(date '+%F %T')] 开始备份 → $BACKUP_DIR"

# 数据库：自定义格式（压缩、可选择性恢复），恢复用 pg_restore
DB_FILE="$BACKUP_DIR/db-$STAMP.dump"
compose exec -T postgres pg_dump -Fc -U lemmy lemmy > "$DB_FILE"
if [ ! -s "$DB_FILE" ]; then
  echo "数据库备份为空，备份失败" >&2
  exit 1
fi
echo "  数据库: $(du -h "$DB_FILE" | cut -f1)  $DB_FILE"

# 图片：pictrs 的数据在 bind mount 的 volumes/pictrs 里
PICTRS_DIR="$COMPOSE_DIR/volumes/pictrs"
if [ -d "$PICTRS_DIR" ]; then
  PICTRS_FILE="$BACKUP_DIR/pictrs-$STAMP.tar.gz"
  tar -C "$COMPOSE_DIR/volumes" -czf "$PICTRS_FILE" pictrs
  echo "  图片:   $(du -h "$PICTRS_FILE" | cut -f1)  $PICTRS_FILE"
fi

# 清理过期备份（只删本脚本生成的文件）
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'db-*.dump' -mtime "+$KEEP_DAYS" -delete
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'pictrs-*.tar.gz' -mtime "+$KEEP_DAYS" -delete
echo "[$(date '+%F %T')] 完成，保留最近 $KEEP_DAYS 天"
echo "恢复：compose exec -T postgres pg_restore -c --if-exists -U lemmy -d lemmy < db-XXX.dump"
