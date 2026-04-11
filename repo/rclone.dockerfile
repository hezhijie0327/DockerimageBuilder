ARG GOLANG_VERSION="1"
ARG NODEJS_VERSION="24"

FROM ghcr.io/hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.rclone" > "${WORKDIR}/rclone.json" \
    && cat "${WORKDIR}/rclone.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/rclone.json" | jq -Sr ".source" > "${WORKDIR}/rclone.source.autobuild" \
    && cat "${WORKDIR}/rclone.json" | jq -Sr ".source_branch" > "${WORKDIR}/rclone.source_branch.autobuild" \
    && cat "${WORKDIR}/rclone.json" | jq -Sr ".patch" > "${WORKDIR}/rclone.patch.autobuild" \
    && cat "${WORKDIR}/rclone.json" | jq -Sr ".patch_branch" > "${WORKDIR}/rclone.patch_branch.autobuild" \
    && cat "${WORKDIR}/rclone.json" | jq -Sr ".version" > "${WORKDIR}/rclone.version.autobuild" \
    && cat "/opt/package.json" | jq -Sr ".repo.rclone_web" > "${WORKDIR}/rclone_web.json" \
    && cat "${WORKDIR}/rclone_web.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/rclone_web.json" | jq -Sr ".source" > "${WORKDIR}/rclone_web.source.autobuild" \
    && cat "${WORKDIR}/rclone_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/rclone_web.source_branch.autobuild" \
    && cat "${WORKDIR}/rclone_web.json" | jq -Sr ".patch" > "${WORKDIR}/rclone_web.patch.autobuild" \
    && cat "${WORKDIR}/rclone_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/rclone_web.patch_branch.autobuild" \
    && cat "${WORKDIR}/rclone_web.json" | jq -Sr ".version" > "${WORKDIR}/rclone_web.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/rclone.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone.source.autobuild") "${WORKDIR}/BUILDTMP/RCLONE" \
    && git clone -b $(cat "${WORKDIR}/rclone.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/rclone_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone_web.source.autobuild") "${WORKDIR}/BUILDTMP/RCLONE_WEB" \
    && export RCLONE_SHA=$(cd "${WORKDIR}/BUILDTMP/RCLONE" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RCLONE_VERSION=$(cat "${WORKDIR}/rclone.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RCLONE_CUSTOM_VERSION="v${RCLONE_VERSION}-ZHIJIE-${RCLONE_SHA}${PATCH_SHA}" \
    && echo "${RCLONE_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/RCLONE/RCLONE_CUSTOM_VERSION" \
    && export RCLONE_WEB_SHA=$(cd "${WORKDIR}/BUILDTMP/RCLONE_WEB" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RCLONE_WEB_VERSION=$(cat "${WORKDIR}/rclone_web.version.autobuild") \
    && export RCLONE_WEB_CUSTOM_VERSION="v${RCLONE_WEB_VERSION}-ZHIJIE-${RCLONE_WEB_SHA}${PATCH_SHA}" \
    && echo "${RCLONE_WEB_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/RCLONE_WEB/RCLONE_CUSTOM_VERSION" \
    && sed -i "s/\"version\": \".*\"/\"version\": \"${RCLONE_WEB_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/RCLONE_WEB/package.json"

FROM node:${NODEJS_VERSION}-slim AS build_rclone_web

WORKDIR /rclone

COPY --from=get_info /tmp/BUILDTMP/RCLONE_WEB /rclone

RUN \
    npm ci \
    && npm run build

FROM golang:${GOLANG_VERSION} AS build_rclone

WORKDIR /rclone

COPY --from=get_info /tmp/BUILDTMP/RCLONE /rclone

COPY --from=build_rclone_web /rclone/dist /rclone/cmd/gui/dist

ENV \
    CGO_ENABLED="0"

RUN \
    go build -trimpath -ldflags "-s -X github.com/rclone/rclone/fs.Version=$(cat '/rclone/RCLONE_CUSTOM_VERSION')" -tags cmount

FROM scratch AS rebased_rclone

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_rclone /rclone/rclone /rclone

FROM scratch

COPY --from=rebased_rclone / /

ENTRYPOINT ["/rclone"]
