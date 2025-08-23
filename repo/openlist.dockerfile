# Current Version: 1.0.1

ARG GOLANG_VERSION="1"
ARG NODEJS_VERSION="22"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.openlist" > "${WORKDIR}/openlist.json" \
    && cat "${WORKDIR}/openlist.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/openlist.json" | jq -Sr ".source" > "${WORKDIR}/openlist.source.autobuild" \
    && cat "${WORKDIR}/openlist.json" | jq -Sr ".source_branch" > "${WORKDIR}/openlist.source_branch.autobuild" \
    && cat "${WORKDIR}/openlist.json" | jq -Sr ".patch" > "${WORKDIR}/openlist.patch.autobuild" \
    && cat "${WORKDIR}/openlist.json" | jq -Sr ".patch_branch" > "${WORKDIR}/openlist.patch_branch.autobuild" \
    && cat "${WORKDIR}/openlist.json" | jq -Sr ".version" > "${WORKDIR}/openlist.version.autobuild" \
    && cat "/opt/package.json" | jq -Sr ".repo.openlist_web" > "${WORKDIR}/openlist_web.json" \
    && cat "${WORKDIR}/openlist_web.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/openlist_web.json" | jq -Sr ".source" > "${WORKDIR}/openlist_web.source.autobuild" \
    && cat "${WORKDIR}/openlist_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/openlist_web.source_branch.autobuild" \
    && cat "${WORKDIR}/openlist_web.json" | jq -Sr ".patch" > "${WORKDIR}/openlist_web.patch.autobuild" \
    && cat "${WORKDIR}/openlist_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/openlist_web.patch_branch.autobuild" \
    && cat "${WORKDIR}/openlist_web.json" | jq -Sr ".version" > "${WORKDIR}/openlist_web.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/openlist.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/openlist.source.autobuild") "${WORKDIR}/BUILDTMP/OPENLIST" \
    && git clone -b $(cat "${WORKDIR}/openlist.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/openlist.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/openlist_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/openlist_web.source.autobuild") "${WORKDIR}/BUILDTMP/OPENLIST_WEB" \
    && export OPENLIST_SHA=$(cd "${WORKDIR}/BUILDTMP/OPENLIST" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export OPENLIST_VERSION=$(cat "${WORKDIR}/openlist.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export OPENLIST_CUSTOM_VERSION="${OPENLIST_VERSION}-ZHIJIE-${OPENLIST_SHA}${PATCH_SHA}" \
    && echo "${OPENLIST_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/OPENLIST/OPENLIST_CUSTOM_VERSION" \
    && cd "${WORKDIR}/BUILDTMP/OPENLIST_WEB" \
    && git submodule update --init \
    && sed -i -e "s/\"version\": \"0.0.0\"/\"version\": \"$OPENLIST_CUSTOM_VERSION\"/g" "${WORKDIR}/BUILDTMP/OPENLIST_WEB/package.json" \
    && unzip "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/openlist/OpenList (zh-CN).zip" -d "${WORKDIR}/BUILDTMP/OPENLIST_WEB"

FROM node:${NODEJS_VERSION}-slim AS build_openlist_web

WORKDIR /openlist

COPY --from=get_info /tmp/BUILDTMP/OPENLIST_WEB /openlist

ENV \
    PNPM_HOME="/pnpm"

RUN \
    export COREPACK_NPM_REGISTRY=$(npm config get registry | sed 's/\/$//') \
    && npm i -g corepack@latest \
    && corepack enable \
    && corepack use $(sed -n 's/.*"packageManager": "\(.*\)".*/\1/p' package.json) \
    && node ./scripts/i18n.mjs \
    && pnpm i \
    && pnpm build

FROM golang:${GOLANG_VERSION} AS build_openlist

WORKDIR /openlist

COPY --from=get_info /tmp/BUILDTMP/OPENLIST /openlist

COPY --from=build_openlist_web /openlist/dist /openlist/public/dist

RUN \
    go build -o ./openlist -ldflags="-w -s -X github.com/OpenListTeam/OpenList/v4/internal/conf.Version=$(cat /openlist/OPENLIST_CUSTOM_VERSION)" -tags=jsoniter .

FROM busybox:latest AS rebased_openlist

WORKDIR /tmp

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_openlist /openlist/openlist /app/openlist/openlist

FROM scratch

COPY --from=rebased_openlist / /

EXPOSE 5221/tcp 5222/tcp 5244/tcp 5246/tcp

ENTRYPOINT ["/app/openlist/openlist"]
