# Current Version: 1.2.4

ARG GOLANG_VERSION="1"
ARG NODEJS_VERSION="22"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.siyuan" > "${WORKDIR}/siyuan.json" \
    && cat "${WORKDIR}/siyuan.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/siyuan.json" | jq -Sr ".source" > "${WORKDIR}/siyuan.source.autobuild" \
    && cat "${WORKDIR}/siyuan.json" | jq -Sr ".source_branch" > "${WORKDIR}/siyuan.source_branch.autobuild" \
    && cat "${WORKDIR}/siyuan.json" | jq -Sr ".patch" > "${WORKDIR}/siyuan.patch.autobuild" \
    && cat "${WORKDIR}/siyuan.json" | jq -Sr ".patch_branch" > "${WORKDIR}/siyuan.patch_branch.autobuild" \
    && cat "${WORKDIR}/siyuan.json" | jq -Sr ".version" > "${WORKDIR}/siyuan.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/siyuan.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/siyuan.source.autobuild") "${WORKDIR}/BUILDTMP/SIYUAN" \
    && git clone -b $(cat "${WORKDIR}/siyuan.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/siyuan.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export SIYUAN_SHA=$(cd "${WORKDIR}/BUILDTMP/SIYUAN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SIYUAN_VERSION=$(cat "${WORKDIR}/siyuan.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SIYUAN_CUSTOM_VERSION="${SIYUAN_VERSION}-ZHIJIE-${SIYUAN_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/SIYUAN" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/siyuan/*.patch \
    && cd "${WORKDIR}/BUILDTMP/SIYUAN/app" \
    && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${SIYUAN_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/SIYUAN/app/package.json" \
    && cd "${WORKDIR}/BUILDTMP/SIYUAN/kernel" \
    && sed -i "s/\=\ \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\=\ \"${SIYUAN_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/SIYUAN/kernel/util/working.go"

FROM node:${NODEJS_VERSION}-slim AS build_siyuan_app

WORKDIR /siyuan

COPY --from=get_info /tmp/BUILDTMP/SIYUAN/app /siyuan

RUN \
    apt update \
    && apt install git -qy \
    && npm install -g pnpm \
    && pnpm i \
    && pnpm run build

FROM golang:${GOLANG_VERSION} AS build_siyuan_kernel

WORKDIR /siyuan

COPY --from=get_info /tmp/BUILDTMP/SIYUAN/kernel /siyuan

ENV CGO_ENABLED="1"

RUN \
    go build --tags fts5 -v -ldflags "-s -w"

FROM busybox:latest AS rebased_siyuan

WORKDIR /tmp

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_siyuan_app /siyuan/appearance /app/siyuan/appearance
COPY --from=build_siyuan_app /siyuan/stage /app/siyuan/stage
COPY --from=build_siyuan_app /siyuan/guide /app/siyuan/guide
COPY --from=build_siyuan_app /siyuan/changelogs /app/siyuan/changelogs

COPY --from=build_siyuan_kernel /siyuan/kernel /app/siyuan/kernel

RUN find /app/siyuan/ -name .git | xargs rm -rf

FROM scratch

ENV SIYUAN_ACCESS_AUTH_CODE_BYPASS="true"

COPY --from=rebased_siyuan / /

EXPOSE 6806/tcp 6808/tcp

ENTRYPOINT ["/app/siyuan/kernel"]
