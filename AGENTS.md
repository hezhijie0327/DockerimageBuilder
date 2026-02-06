# DockerimageBuilder - Agent Guide

## Project Overview

DockerimageBuilder is a multi-platform Docker image building project that creates custom Docker images for various open-source applications. The project uses GitHub Actions workflows to build and publish images to both Docker Hub and GitHub Container Registry.

## Build Commands

### Local Testing
```bash
# Test a specific module build
docker build -f module/alpine.dockerfile --platform linux/amd64 .

# Test a specific package build
docker build -f repo/browserless.dockerfile --platform linux/amd64 .

# Build for multiple platforms
docker buildx build -f module/alpine.dockerfile --platform linux/amd64,linux/arm64 .
```

### Release Management
```bash
# Update package versions (runs automatically via GitHub Actions)
bash ./patch/release.sh

# This script:
# 1. Fetches latest versions from GitHub APIs
# 2. Generates a new package.json with updated versions
# 3. Prepares for automated builds
```

## Project Structure

```
├── module/          # Base module Dockerfiles (alpine, openssl)
├── repo/           # Application-specific Dockerfiles
├── patch/          # Source patches and version management
│   ├── browserless/
│   ├── lobehub/
│   └── ...
├── .github/
│   └── workflows/  # CI/CD pipelines
└── LICENSE
```

## Code Style Guidelines

### Dockerfile Conventions
1. **Multi-stage builds**: All Dockerfiles use multi-stage builds for optimization
2. **ARG declarations**: Define build arguments at the top of the file with default values
3. **Naming conventions**:
   - Use lowercase for stage names: `get_info`, `build_*`
   - Use descriptive names that indicate the stage's purpose
4. **Base images**: 
   - Use specific version tags when possible (e.g., `node:24-slim`)
   - Reference custom modules using ghcr.io path
5. **Environment variables**: Use uppercase with underscores: `DEBIAN_FRONTEND`, `WORKDIR`
6. **Directory structure**: 
   - WORKDIR should be set appropriately for each stage
   - Use /tmp for temporary files and /app for application files
7. **Cleanup**: Always remove temporary files and caches in final stages

### Shell Script Conventions
1. **Functions**: Use PascalCase for function names: `GetLatestVersion`, `GenerateReplacements`
2. **Variables**: Use UPPER_SNAKE_CASE for environment variables and exports
3. **Error handling**: Check for errors after critical operations
4. **Comments**: Add section headers with `##` for major sections

### JSON Configuration
1. **Version tracking**: All package versions managed in patch/package.json
2. **Structure**: 
   - Top-level: `module` and `repo` sections
   - Each entry: `source`, `patch`, `version`, and branch information
3. **Updates**: Version updates handled by release.sh script

## Workflow Processes

### Module Build Process
1. `module.yml` workflow triggers on schedule or manual dispatch
2. Updates package.json via release.sh
3. Builds modules (alpine, openssl) for both amd64 and arm64
4. Pushes to both Docker Hub and GHCR
5. Creates multi-platform manifests

### Package Build Process
1. `package.yml` workflow triggers on schedule or manual dispatch
2. Builds each application package in parallel
3. Uses patches from corresponding directories
4. Applies version customization
5. Creates multi-platform manifests

## Patch Management

1. **Patch structure**: Each application has its own patch directory
2. **Patch naming**: Use numerical prefix with descriptive name: `1001-feat-startServer.patch`
3. **Patch application**: Patches applied during build process via `git apply`
4. **Version customization**: Application versions are modified to include build SHA values

## Development Guidelines

1. **Testing new packages**:
   - Create new Dockerfile in `repo/` directory
   - Add package entry to `patch/template.json`
   - Create patch directory if modifications needed
   - Test locally with docker build before committing

2. **Version updates**:
   - Modify version fetching in `release.sh` if API changes
   - Test release script locally before running in CI

3. **Modifying existing builds**:
   - Update patch files as needed
   - Test changes locally
   - Ensure cross-platform compatibility

## Multi-Platform Support

All builds support both:
- linux/amd64 (built on ubuntu-24.04)
- linux/arm64 (built on ubuntu-24.04-arm)

Ensure your changes work on both architectures before committing.