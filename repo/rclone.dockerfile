ARG GOLANG_VERSION="1"

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
    && git clone -b $(cat "${WORKDIR}/rclone.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone.source.autobuild") "${WORKDIR}/BUILDTMP/RCLONE" \
    && git clone -b $(cat "${WORKDIR}/rclone.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export RCLONE_SHA=$(cd "${WORKDIR}/BUILDTMP/RCLONE" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RCLONE_VERSION=$(cat "${WORKDIR}/rclone.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RCLONE_CUSTOM_VERSION="v${RCLONE_VERSION}-ZHIJIE-${RCLONE_SHA}${PATCH_SHA}" \
    && echo "${RCLONE_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/RCLONE/RCLONE_CUSTOM_VERSION"

FROM golang:${GOLANG_VERSION} AS build_rclone

WORKDIR /rclone

COPY --from=get_info /tmp/BUILDTMP/RCLONE /rclone

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
