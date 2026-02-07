# DockerimageBuilder

DockerimageBuilder 是一个多平台Docker镜像构建项目，为各种开源应用程序创建自定义Docker镜像。项目使用GitHub Actions工作流自动构建和发布镜像到Docker Hub和GitHub Container Registry。

## 特性

- 🐳 多平台支持（linux/amd64, linux/arm64）
- 🔄 自动化版本更新和发布
- 📦 多种开源应用程序镜像
- 🛠️ 自定义补丁和构建配置
- 🚀 CI/CD自动化构建流程

## 快速开始

### 拉取镜像

```bash
# 从GitHub Container Registry拉取
docker pull ghcr.io/hezhijie0327/[image-name]:latest

# 从Docker Hub拉取
docker pull hezhijie0327/[image-name]:latest
```

## 项目结构

```
DockerimageBuilder/
├── module/          # 基础模块Dockerfile
├── repo/           # 应用程序Dockerfile
├── patch/          # 源码补丁和版本管理
├── .github/
│   └── workflows/  # CI/CD工作流
└── AGENTS.md       # 开发者指南
```

## 许可证

本项目采用Apache License 2.0 with Commons Clause v1.0许可证 - 详见[LICENSE](LICENSE)文件
