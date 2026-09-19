# Lemmy 生产部署（mouth.niuma.club）

这个目录放**运维相关的东西**，故意放在两个 git 仓库之外，避免污染补丁序列。
唯一进仓库的是 `lemmy/docker/docker-compose.prod.yml` 和 `lemmy/docker/Caddyfile`
（因为它们的相对路径必须跟着 compose 走，而且它们属于"部署版本"的一部分）。

## 文件清单

| 文件 | 作用 |
| --- | --- |
| `.env.example` | 变量模板：域名、邮箱、口令、SMTP。复制成 `.env` 后填 |
| `write-config.sh` | 读 `.env` 生成 `lemmy.prod.hjson`；缺的密码自动生成并写回 `.env` |
| `bootstrap-site.sh` | 新实例初始化：站点名、申请问题、语言、管理员显示名、站点图标 |
| `backup.sh` | 备份数据库 + 图片，保留 N 天，配 cron 每天跑 |
| `health-check.sh` | 部署后验收：容器、端口、证书跳转、API、子域名校验、联邦发现 |
| `../lemmy/docker/docker-compose.prod.yml` | 生产 override：caddy(80/443)、内部端口不外露 |
| `../lemmy/docker/Caddyfile` | 自动 HTTPS + Lemmy 的路由规则 |

## 前置条件

- VPS：建议 **2 核 4G 起**，磁盘 ≥ 40G（镜像 + 构建缓存 + 备份）。内存 ≤2G 时不要在服务器上编译 Rust，见下面"构建方式"。
- 系统装了 Docker 与 compose **≥ 2.24**（`docker compose version` 确认，override 里用到 `!override`/`!reset`）。
- `mouth.niuma.club` 的 A 记录已指向 VPS IP（你的记录：`mouth.niuma.club. A 69.33.212.6`）。
  证书签发必须，签不下来一般是这步没生效（用 `dig +short mouth.niuma.club` 确认）。
- 防火墙只开 22/80/443。

## 部署步骤

### 1. 上传代码

在本地执行（排除依赖、构建产物和数据目录）：

```bash
rsync -av --delete \
  --exclude node_modules --exclude dist --exclude target \
  --exclude 'docker/volumes' --exclude backups \
  ~/Desktop/projects/lemmy ~/Desktop/projects/lemmy-ui ~/Desktop/projects/lemmy-deploy \
  user@VPS:~
```

### 2. 准备配置

```bash
cd ~/lemmy-deploy
cp .env.example .env
vim .env                 # 填 LEMMY_DOMAIN / ACME_EMAIL，以及 QQ 邮箱的 SMTP 授权码
./write-config.sh        # 生成 lemmy.prod.hjson，并自动补齐数据库/pictrs 随机口令
```

### 3. 构建镜像

**VPS 有 ≥4G 可用内存**：直接在服务器构建（首次约 20-40 分钟）

```bash
cd ~/lemmy/docker
docker compose --env-file ../../lemmy-deploy/.env \
  -f docker-compose.yml -f docker-compose.prod.yml build
```

**VPS 内存不足**：在本地交叉编译 amd64 镜像再传过去

```bash
# 本地（Apple Silicon 上会走模拟，慢但可行）
cd ~/Desktop/projects/lemmy/docker
docker buildx build --platform linux/amd64 -t docker-lemmy:latest -f Dockerfile ../
cd ~/Desktop/projects/lemmy-ui
docker buildx build --platform linux/amd64 -t docker-lemmy-ui:latest -f dev.dockerfile .
docker save docker-lemmy:latest docker-lemmy-ui:latest | gzip > /tmp/lemmy-images.tgz
scp /tmp/lemmy-images.tgz user@VPS:/tmp/
# 服务器
gunzip -c /tmp/lemmy-images.tgz | docker load
```

### 4. 启动

```bash
cd ~/lemmy/docker
docker compose --env-file ../../lemmy-deploy/.env \
  -f docker-compose.yml -f docker-compose.prod.yml up -d
docker compose --env-file ../../lemmy-deploy/.env \
  -f docker-compose.yml -f docker-compose.prod.yml ps
```

Caddy 会自动申请证书；第一次启动 `proxy` 可能要等十几秒。

### 5. 建站

如果 `.env` 里填了 `ADMIN_PASSWORD`，实例已按配置自动建好管理员；否则打开
`https://mouth.niuma.club` 会进入建站向导，自己填管理员用户名（建议 `niuma`）和密码。

然后跑初始化脚本（站点名、语言、申请问题、显示名、图标）：

```bash
cd ~/lemmy-deploy
./bootstrap-site.sh
```

### 6. 验收

```bash
./health-check.sh
```

全绿才算部署完成。重点看三项：证书跳转、子域名校验（说明 UI 容器能访问 hapdns.com）、
webfinger（说明联邦能被别的实例发现）。

### 7. 定时备份

```bash
crontab -e
# 每天 4 点备份，保留 14 天
0 4 * * * /home/USER/lemmy-deploy/backup.sh >> /var/log/lemmy-backup.log 2>&1
```

恢复用 `pg_restore`（脚本末尾会打印命令）。**建议再加一步异地备份**：把 `backups/`
定期 rsync 到另一台机器或对象存储。

## 常见问题

- **证书签不下来**：DNS 没生效或 80 端口不通。`docker compose logs proxy` 看 Caddy 的报错。
- **联邦不通**：确认 `https://mouth.niuma.club/.well-known/webfinger?resource=acct:niuma@mouth.niuma.club` 返回 200；再看 443 是否对外开放。
- **邮件发不出去**：`.env` 里的 `SMTP_PASSWORD` 必须是 QQ 邮箱生成的**授权码**（16 位），不是登录密码；端口 465 配 `SMTP_TLS=smtps`。生成的配置里 `connection` 形如
  `smtps://you%40qq.com:授权码@smtp.qq.com:465`（`@` 写成 `%40` 是 lettre 要求的 URL 编码，它读的时候会解码回来）。
- **站点身份写错了**：`hostname` 必须在**首次建站前**定好。一旦建站，站点和所有用户的 `ap_id` 都绑定了域名，改域名等于换身份（本地数据库里的 `https://localhost/...` 就是这个原因，所以本地库不能搬到生产）。
- **编译时 OOM**：见"构建方式"的第二种，本地编译好再传。
- **注册页提示"暂时无法校验"**：UI 容器访问不到 `hapdns.com`，检查服务器出网/DNS。

## 上线后待办

- **AGPL：提供源码获取途径**。用 `lemmy-patches/` 里的补丁建公开仓库，或在页脚放「源代码」链接。
- 确认 QQ 邮箱 SMTP 可用（发一封注册申请通知试试）；用户重置密码、注册申请提醒都依赖它。
- 定期 `git fetch && git rebase origin/main` 跟进上游，然后重跑构建与验收。
