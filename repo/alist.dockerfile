# Current Version: 1.2.1

ARG GOLANG_VERSION="1"
ARG NODEJS_VERSION="22"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.alist" > "${WORKDIR}/alist.json" \
    && cat "${WORKDIR}/alist.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/alist.json" | jq -Sr ".source" > "${WORKDIR}/alist.source.autobuild" \
    && cat "${WORKDIR}/alist.json" | jq -Sr ".source_branch" > "${WORKDIR}/alist.source_branch.autobuild" \
    && cat "${WORKDIR}/alist.json" | jq -Sr ".patch" > "${WORKDIR}/alist.patch.autobuild" \
    && cat "${WORKDIR}/alist.json" | jq -Sr ".patch_branch" > "${WORKDIR}/alist.patch_branch.autobuild" \
    && cat "${WORKDIR}/alist.json" | jq -Sr ".version" > "${WORKDIR}/alist.version.autobuild" \
    && cat "/opt/package.json" | jq -Sr ".repo.alist_web" > "${WORKDIR}/alist_web.json" \
    && cat "${WORKDIR}/alist_web.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/alist_web.json" | jq -Sr ".source" > "${WORKDIR}/alist_web.source.autobuild" \
    && cat "${WORKDIR}/alist_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/alist_web.source_branch.autobuild" \
    && cat "${WORKDIR}/alist_web.json" | jq -Sr ".patch" > "${WORKDIR}/alist_web.patch.autobuild" \
    && cat "${WORKDIR}/alist_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/alist_web.patch_branch.autobuild" \
    && cat "${WORKDIR}/alist_web.json" | jq -Sr ".version" > "${WORKDIR}/alist_web.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/alist.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/alist.source.autobuild") "${WORKDIR}/BUILDTMP/ALIST" \
    && git clone -b $(cat "${WORKDIR}/alist.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/alist.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/alist_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/alist_web.source.autobuild") "${WORKDIR}/BUILDTMP/ALIST_WEB" \
    && export ALIST_SHA=$(cd "${WORKDIR}/BUILDTMP/ALIST" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export ALIST_VERSION=$(cat "${WORKDIR}/alist.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export ALIST_CUSTOM_VERSION="${ALIST_VERSION}-ZHIJIE-${ALIST_SHA}${PATCH_SHA}" \
    && echo "${ALIST_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/ALIST/ALIST_CUSTOM_VERSION" \
    && cd "${WORKDIR}/BUILDTMP/ALIST_WEB" \
    && git submodule update --init \
    && sed -i -e "s/\"version\": \"0.0.0\"/\"version\": \"$ALIST_CUSTOM_VERSION\"/g" "${WORKDIR}/BUILDTMP/ALIST_WEB/package.json" \
    && cp -rf "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/alist_web/lang/zh-CN" "${WORKDIR}/BUILDTMP/ALIST_WEB/src/lang/zh-CN"

FROM --platform=linux/amd64 node:${NODEJS_VERSION}-slim AS build_alist_web

WORKDIR /alist

COPY --from=get_info /tmp/BUILDTMP/ALIST_WEB /alist

RUN \
    export PNPM_HOME="/pnpm" \
    && corepack enable \
    && corepack use pnpm@9 \
    && node ./scripts/i18n.mjs \
    && pnpm i \
    && pnpm build

FROM golang:${GOLANG_VERSION} AS build_alist

WORKDIR /alist

COPY --from=get_info /tmp/BUILDTMP/ALIST /alist

COPY --from=build_alist_web /alist/dist /alist/public/dist

RUN \
    go build -o ./alist -ldflags="-w -s -X github.com/alist-org/alist/v3/internal/conf.Version=$(cat /alist/ALIST_CUSTOM_VERSION)" -tags=jsoniter .

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=build_alist /alist/alist /tmp/BUILDKIT/alist

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/alist"

FROM busybox:latest AS rebased_alist

WORKDIR /tmp

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=gpg_sign /tmp/BUILDKIT /opt/alist

FROM scratch

COPY --from=rebased_alist / /

EXPOSE 5221/tcp 5222/tcp 5244/tcp 5246/tcp

ENTRYPOINT ["/opt/alist/alist"]
