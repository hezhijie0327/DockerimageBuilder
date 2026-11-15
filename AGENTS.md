# AGENTS.md

DockerimageBuilder is a multi-platform Docker image building project that creates custom Docker images for various open-source applications. The project uses GitHub Actions workflows to build and publish images to both Docker Hub and GitHub Container Registry. See [README.md](README.md) for the Chinese overview.

## HANDOVER.md

When a multi-step task is interrupted, write progress to `HANDOVER.md` so the next session can pick up where you left off. Include: what was done, what remains, key decisions made, and the next concrete step. Delete the file when the task is complete.

## Behavioral Guidelines

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

**Additional rules:**
- Be concise in output but thorough in reasoning.
- Do not re-read files you have already read.
- User instructions always override this file.
- Don't wrestle with indentation in the Edit tool — focus on logic, let the project's formatter fix formatting. Use `sed` or `python3` freely when the Edit tool struggles with whitespace.

## Git commit convention

Every commit subject starts with a type prefix — `feat` / `fix` / `chore` / `docs` / `revert` / `refactor` / `perf` / `test` / `build` — optionally scoped: `fix(toolbar): ...`. Subject: imperative, lowercase start, no trailing period, aim ≤ 72 chars; detail goes in the body after a blank line (why, not what); breaking changes take `!` before the colon or a `BREAKING CHANGE:` body footer. Never rewrite pushed history.

- Commit incrementally — one logical change per commit, after lint and tests pass. Present changes for review before committing.
- PRs: link the issue, summarize the change and verification (tests/benchmarks), and include config/log/pprof evidence for bug fixes.

### Co-Author Format

- Always add co-author information. If closing an issue in commit text, verify against `main` first: `gh issue view <issue-id>`.
- Only ONE co-author line is allowed. If multiple agents contributed, aggregate into ONE entry.

Format: `Co-authored-by: <AgentName> <Email>`

Valid examples (choose EXACTLY ONE):

```
Co-authored-by: ZCode <noreply@z.ai>
```

## Documentation format

Family-wide Markdown rules, shared verbatim across all ZJ projects:

- **Language**: AGENTS.md, AUDIT.md, DESIGN.md and other agent-facing docs are English; README.md is Chinese (human-facing). Keep literal UI strings and code identifiers verbatim.
- **AGENTS.md skeleton** — generic sections first, then project; omit sections that don't apply, keep the order:
  `# AGENTS.md` → 1–2 sentence intro (what the project is + key doc links) → Behavioral Guidelines → Git commit convention → Documentation format → Project → Commands → Architecture → Conventions (Gotchas as a subsection) → project-specific sections → Key Docs.
- **README.md skeleton**: `# <project>` → badge block → one-line positioning + stack + key links → 特性 → 快速开始 → 配置 / 用法 → 文档 → License (omit as needed).
- **README badges** (shields.io, after the title, in order): Version (only where a real version exists, linked to the repo's GitHub releases), License (Apache 2.0 with Commons Clause — every project), primary-language badge (Go / TypeScript / Bash / Python / Docker), Biome for TypeScript projects; pure data/config repos get License only. Version links use the real GitHub repo name.
- **Formatting**: ATX headings (`#`), never skip a level; code fences always carry a language tag (`bash`, `go`, `json`, `text` for trees); tables for structured reference; no decorative emoji in headings or bullets; bold for key terms only.

## Project

DockerimageBuilder is a multi-platform Docker image building project that creates custom Docker images for various open-source applications. The project uses GitHub Actions workflows to build and publish images to both Docker Hub and GitHub Container Registry.

## Commands

### Local Testing
```bash
# Test a specific package build (versions resolve to latest at build time)
docker build -f images/xray.dockerfile --platform linux/amd64 .

# Pin a component version
docker build -f images/xray.dockerfile --build-arg XRAY_VERSION=26.9.9 .

# Build for multiple platforms
docker buildx build -f images/xray.dockerfile --platform linux/amd64,linux/arm64 .
```

There is no release/version-update script: each Dockerfile's `get_info` stage resolves the latest upstream tag from the GitHub API at build time.

## Project structure

```text
├── images/         # Application-specific Dockerfiles (self-contained)
├── patches/        # Source patches, one directory per application
│   ├── qbittorrent/
│   ├── siyuan/
│   └── xray/
├── .github/
│   └── workflows/  # CI/CD pipelines (repo.yml)
└── LICENSE
```

## Conventions

### Dockerfile Conventions
1. **Multi-stage builds**: All Dockerfiles use multi-stage builds for optimization
2. **ARG declarations**: Define build arguments at the top of the file with default values
3. **Naming conventions**:
   - Use lowercase for stage names: `get_info`, `build_*`
   - Use descriptive names that indicate the stage's purpose
4. **Base images**: 
   - Use specific version tags when possible (e.g., `node:24-slim`)
   - Use upstream images directly (`alpine:latest` for `get_info`); no custom base images
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

### Version Resolution
1. **Build-time lookup via the git protocol**: `get_info` resolves the latest tag with `git ls-remote`, not the REST API. `api.github.com` is rate-limited to 60 req/h per IP and the shared runners exhaust it; the git protocol is not, so no token is needed. Canonical pipeline:
   ```bash
   git ls-remote --tags --sort=-v:refname "https://github.com/<owner>/<repo>.git" \
     | awk '{print $2}' | grep -v '\^{}' \
     | jq -Rr 'select(test("<filter>"))' | head -n1 | sed 's|^<prefix>||'
   ```
   `--sort=-v:refname` orders by version so `head -n1` is the true latest; `grep -v '\^{}'` drops peeled annotated-tag refs; `<filter>` is a jq `test()` regex (Oniguruma, supports lookahead).
2. **Pinning**: each component version is an ARG (e.g., `XRAY_VERSION`); an empty default resolves latest, a passed value pins it (`${XRAY_VERSION:-$(...)}` short-circuits the lookup when set).
3. **Source vs label**: clone the branch HEAD for source (patches target the branch); the resolved tag is only the version label.
4. **PATCH_SHA**: ARG defaulting to `0000`; CI passes the first 4 chars of `GITHUB_SHA` uppercased.

### Self-Contained Build Pattern
New app Dockerfiles follow the same shape (see `images/xray.dockerfile`):
1. `ARG <APP>_VERSION=""` and `ARG PATCH_SHA="0000"` at the top, re-declared in `get_info`.
2. `get_info` based on `alpine:latest`; install tools (`apk add --no-cache curl git jq`, plus `gnupg` when needed) in their own RUN layer.
3. Resolve the version (pipeline above), guard with `[ -n "${<APP>_VERSION}" ]`, clone the source branch, compute the source SHA, build the `-ZHIJIE-<SRC><PATCH>` custom version.
4. `COPY patches/<app> /tmp/patches` from the build context and `git apply` them.
5. Fetch the CA bundle to a separate file, then `mv` it to `/etc/ssl/certs/ca-certificates.crt`; final stages `COPY --from=get_info` that bundle.

### Gotchas
- **Never redirect a download into the live CA bundle**: `curl ... > /etc/ssl/certs/ca-certificates.crt` truncates the bundle before curl reads it as its own CAfile, failing with exit 77 (`SSL_CACERT_BADFILE`). Download to a separate file then `mv` (or COPY into the final image).
- **Version sort, not alphabetical**: `--sort=-v:refname` + `head -n1` picks the true latest tag; an alphabetical `last` under-reports (e.g. vaultwarden `1.9.1` vs `1.37.5`).
- **Wrap long RUN lines**: break command substitutions and sed script/target args across continuation lines rather than one oversized line.

## Workflow Processes

### Package Build Process
1. `repo.yml` workflow triggers on schedule or manual dispatch
2. Builds each application package in parallel (matrix in the workflow)
3. Each Dockerfile resolves versions, clones sources, and applies patches from `patches/<app>/` via build context
4. Applies version customization (`-ZHIJIE-<SRC><PATCH>` suffix)
5. Pushes to both Docker Hub and GHCR, creates multi-platform manifests

## Patch Management

1. **Patch structure**: Each application has its own patch directory
2. **Patch naming**: Use numerical prefix with descriptive name: `1001-feat-startServer.patch`
3. **Patch application**: Patches are `COPY`ed from the build context into `get_info` and applied via `git apply`
4. **Version customization**: Application versions are modified to include build SHA values

## Development Guidelines

1. **Testing new packages**:
   - Create new Dockerfile in `images/` directory
   - Add the package to both matrices (build and merge) in `repo.yml`
   - Create patch directory if modifications needed
   - Test locally with docker build before committing

2. **Version filters**:
   - Tag filter regexes live in each Dockerfile's `get_info` stage
   - Verify the `git ls-remote` pipeline resolves the expected tag before committing

3. **Modifying existing builds**:
   - Update patch files as needed
   - Test changes locally
   - Ensure cross-platform compatibility

## Multi-Platform Support

All builds support both:
- linux/amd64 (built on ubuntu-24.04)
- linux/arm64 (built on ubuntu-24.04-arm)

Ensure your changes work on both architectures before committing.
