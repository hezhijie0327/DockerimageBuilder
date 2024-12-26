# Current Version: 1.1.9

ARG GOLANG_VERSION="1"

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.xray" > "${WORKDIR}/xray.json" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".source" > "${WORKDIR}/xray.source.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".source_branch" > "${WORKDIR}/xray.source_branch.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".patch" > "${WORKDIR}/xray.patch.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".patch_branch" > "${WORKDIR}/xray.patch_branch.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".version" > "${WORKDIR}/xray.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/xray.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/xray.source.autobuild") "${WORKDIR}/BUILDTMP/XRAY" \
    && git clone -b $(cat "${WORKDIR}/xray.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/xray.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export XRAY_SHA=$(cd "${WORKDIR}/BUILDTMP/XRAY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export XRAY_VERSION=$(cat "${WORKDIR}/xray.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export XRAY_CUSTOM_VERSION="${XRAY_VERSION}-ZHIJIE-${XRAY_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/XRAY" \
    && sed -i "s/Version_x, Version_y, Version_z/\"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 1)\", \"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 2)\", \"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 3)\"/g" "${WORKDIR}/BUILDTMP/XRAY/core/core.go"

FROM golang:${GOLANG_VERSION} AS build_xray

WORKDIR /xray

COPY --from=get_info /tmp/BUILDTMP/XRAY /xray

ENV \
    CGO_ENABLED="0"

RUN \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt

COPY --from=build_xray /xray/xray /tmp/BUILDKIT/xray

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/xray"

FROM scratch

COPY --from=gpg_sign /tmp/BUILDKIT /

ENTRYPOINT ["/xray"]
