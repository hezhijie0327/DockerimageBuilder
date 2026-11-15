# DockerimageBuilder

[![License](https://img.shields.io/badge/License-Apache%202.0--Commons%20Clause-blue)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)](https://www.python.org/)

多平台 Docker 镜像构建项目：为开源应用打自定义补丁并构建 linux/amd64 / linux/arm64 镜像，自动发布到 Docker Hub 与 GHCR。开发规范见 [AGENTS.md](AGENTS.md)。

## 特性

- **多平台**：linux/amd64 + linux/arm64，按 digest 构建后合并多架构 manifest
- **自动版本跟踪**：`versions/update.py` 从 GitHub tags 解析各组件最新版本（支持环境变量固定版本）
- **自定义补丁**：qBittorrent DHT 节点/构建修复、思源 VIP 解锁、Xray 反向补丁等
- **版本号定制**：产物版本嵌入源码与补丁仓库 SHA（`-ZHIJIE-<SRC><PATCH>`）
- **双仓库发布**：Docker Hub + GitHub Container Registry

## 镜像列表

| 镜像 | 说明 |
| ---- | ---- |
| `base:alpine` | 共享基础镜像（工具链 + CA 证书 + 版本元数据） |
| `cloudflared` | Cloudflare Tunnel 客户端 |
| `jellyfin` | 媒体服务器（含 jellyfin-web） |
| `qbittorrent` | qBittorrent-nox 静态构建 + VueTorrent |
| `siyuan` | 思源笔记 |
| `vaultwarden` | Bitwarden 兼容服务器（含 web vault） |
| `xray` | Xray-core |

## 快速开始

### 拉取镜像

```bash
# GitHub Container Registry
docker pull ghcr.io/hezhijie0327/qbittorrent:latest

# Docker Hub
docker pull hezhijie0327/qbittorrent:latest
```

### 本地构建

```bash
git clone https://github.com/hezhijie0327/DockerimageBuilder.git
cd DockerimageBuilder

# 更新版本元数据（Python 3.9+，仅标准库）
python3 versions/update.py

# 构建单个镜像
docker build -f images/repo/xray.dockerfile --platform linux/amd64 .
```

## 项目结构

```text
DockerimageBuilder/
├── images/
│   ├── base/alpine.dockerfile    # 基础镜像（内嵌 versions/package.json）
│   └── repo/*.dockerfile         # 应用镜像定义
├── patches/<app>/*.patch         # 源码补丁
├── versions/
│   ├── template.json             # 版本占位符模板
│   ├── package.json              # 生成的版本元数据（CI 自动提交）
│   └── update.py                 # 版本解析脚本
└── .github/workflows/            # base.yml / repo.yml
```

## 配置

固定某个组件的版本（跳过自动解析）：

```bash
XRAY_VERSION_FIXED=26.9.9 python3 versions/update.py
```

可用的固定变量：`CLOUDFLARED_VERSION_FIXED`、`JELLYFIN_VERSION_FIXED`、`JELLYFIN_WEB_VERSION_FIXED`、`QBITTORRENT_VERSION_FIXED`、`SIYUAN_VERSION_FIXED`、`VAULTWARDEN_VERSION_FIXED`、`VAULTWARDEN_WEB_VERSION_FIXED`、`VUETORRENT_VERSION_FIXED`、`XRAY_VERSION_FIXED`。

## 文档

- [AGENTS.md](AGENTS.md) — 开发规范与实现细节（英文）

## License

[Apache License 2.0 with Commons Clause v1.0](LICENSE)
