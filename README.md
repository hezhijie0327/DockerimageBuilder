# DockerimageBuilder

[![License](https://img.shields.io/badge/License-Apache%202.0--Commons%20Clause-blue)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)

多平台 Docker 镜像构建项目：为开源应用打自定义补丁并构建 linux/amd64 / linux/arm64 镜像，自动发布到 Docker Hub 与 GHCR。开发规范见 [AGENTS.md](AGENTS.md)。

## 特性

- **多平台**：linux/amd64 + linux/arm64，按 digest 构建后合并多架构 manifest
- **实时版本跟踪**：构建时从 GitHub tags 实时解析各组件最新版本（可用 build-arg 固定版本）
- **自定义补丁**：按应用维护源码补丁（`patches/<app>/`），构建时自动应用
- **版本号定制**：产物版本嵌入源码与补丁仓库 SHA（`-ZHIJIE-<SRC><PATCH>`）
- **双仓库发布**：Docker Hub + GitHub Container Registry

## 快速开始

### 拉取镜像

```bash
# GitHub Container Registry
docker pull ghcr.io/hezhijie0327/<image>:latest

# Docker Hub
docker pull hezhijie0327/<image>:latest
```

### 本地构建

```bash
git clone https://github.com/hezhijie0327/DockerimageBuilder.git
cd DockerimageBuilder

# 构建单个镜像（版本在构建时自动解析为最新）
docker build -f images/<app>.dockerfile --platform linux/amd64 .
```

## 项目结构

```text
DockerimageBuilder/
├── images/*.dockerfile           # 应用镜像定义（自包含：版本解析 + 源码拉取 + 补丁应用）
├── patches/<app>/*.patch         # 源码补丁
└── .github/workflows/repo.yml    # 构建与发布
```

## 配置

固定某个组件的版本（跳过实时解析）：

```bash
docker build -f images/xray.dockerfile --build-arg XRAY_VERSION=26.9.9 .
```

可用的版本参数：`CLOUDFLARED_VERSION`、`JELLYFIN_VERSION`、`JELLYFIN_WEB_VERSION`、`QBITTORRENT_VERSION`、`SIYUAN_VERSION`、`VAULTWARDEN_VERSION`、`VAULTWARDEN_WEB_VERSION`、`VUETORRENT_VERSION`、`XRAY_VERSION`。不传时构建时从 GitHub 解析最新 tag。

`PATCH_SHA`（版本号中嵌入的补丁仓库 SHA）默认为 `0000`，CI 自动传入当前提交 SHA 的前 4 位（大写）。

## 文档

- [AGENTS.md](AGENTS.md) — 开发规范与实现细节（英文）

## License

[Apache License 2.0 with Commons Clause v1.0](LICENSE)
