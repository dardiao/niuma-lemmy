# 牛马俱乐部 — Lemmy 实例源码

这个仓库是 **https://mouth.niuma.club** 这个 Lemmy 实例所使用的完整源代码。

按 AGPL-3.0 第 13 条的要求，任何通过网络与本实例交互的人都有权获得这份"对应源码"：
它包含了运行该实例所需的全部源代码，以及我们对上游所做的全部修改。

## 基于什么

| 上游仓库 | 基线提交 | 说明 |
| --- | --- | --- |
| [LemmyNet/lemmy](https://github.com/LemmyNet/lemmy) | `646f5a0`（2026-09-16） | 后端，Rust |
| [LemmyNet/lemmy-ui](https://github.com/LemmyNet/lemmy-ui) | `dd31e56e`（2026-09-14） | 前端，TypeScript + Inferno |

对应上游 `main` 开发线（版本号字符串为 `1.0.0-beta.2`），不是 0.19.x 稳定线。
`lemmy-translations` 子模块的提交是 `1c22d5e`，前端依赖 `lemmy-js-client@1.0.0-list-community-followers.2`。

## 目录结构

```
lemmy/          后端源码（含 docker/ 下的开发与生产 compose）
lemmy-ui/       前端源码
lemmy-deploy/   部署与运维脚本（配置生成、站点初始化、备份、验收）
patches/        相对上述基线提交的补丁，逐个提交列出，便于对照
LICENSE         AGPL-3.0（与上游相同）
```

## 我们改了什么

完整改动见 `patches/`，要点是：

- **界面去标识**：去掉指向上游的链接与图标，换成站点自己的名称、图标（「牛马」+ 领带 + 汗滴）和文案
- **注册与子域名绑定**：用户名必须是在 [HapDNS](https://hapdns.com) 注册过的 `<名字>.niuma.club`
  子域（前端在失焦时通过同源接口校验，规则与提示见 `lemmy-ui/src/shared/utils/config.ts`）
- **本地/生产运行栈**：健康检查与启动顺序、生产用 Caddy 自动 HTTPS、不再对外暴露内部端口
- **离线构建适配**：构建镜像走镜像内的 Rust 工具链，不依赖公网同步工具链

## 部署

见 [`lemmy-deploy/README.md`](lemmy-deploy/README.md)。简要流程：准备 `.env` →
`write-config.sh` 生成配置 → 构建镜像 → `docker compose` 启动 → 建站 → `bootstrap-site.sh` →
`health-check.sh` 验收 → 配好每日备份。

## 许可证与修改声明

本仓库是上游项目的**修改版**，依据 AGPL-3.0 分发，许可证全文见 `LICENSE`。
修改由本实例的运营者完成，修改时间自 2026-09 起；版权归原作者（Dessalines 及 Lemmy 贡献者）所有。
如果你在本实例上看到的内容与上游行为不同，那就是本地修改导致的。

联系方式：<contact@hapdns.com>
