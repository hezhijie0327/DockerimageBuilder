# Current Version: 1.1.3

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.cloudflared" > "${WORKDIR}/cloudflared.json" \
    && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".source" > "${WORKDIR}/cloudflared.source.autobuild" \
    && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".source_branch" > "${WORKDIR}/cloudflared.source_branch.autobuild" \
    && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".patch" > "${WORKDIR}/cloudflared.patch.autobuild" \
    && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".patch_branch" > "${WORKDIR}/cloudflared.patch_branch.autobuild" \
    && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".version" > "${WORKDIR}/cloudflared.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/cloudflared.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/cloudflared.source.autobuild") "${WORKDIR}/BUILDTMP/CLOUDFLARED" \
    && git clone -b $(cat "${WORKDIR}/cloudflared.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/cloudflared.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export CLOUDFLARED_SHA=$(cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export CLOUDFLARED_VERSION=$(cat "${WORKDIR}/cloudflared.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export CLOUDFLARED_CUSTOM_VERSION="${CLOUDFLARED_VERSION}-ZHIJIE-${CLOUDFLARED_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" \
    && sed -i "s/\$(shell git describe --tags --always --match \"\[0-9\]\[0-9\]\[0-9\]\[0-9\].\*.\*\")/${CLOUDFLARED_CUSTOM_VERSION}/g" "${WORKDIR}/BUILDTMP/CLOUDFLARED/Makefile"

FROM golang:latest AS build_cloudflared

WORKDIR /cloudflared

COPY --from=get_info /tmp/BUILDTMP/CLOUDFLARED /cloudflared

ENV CGO_ENABLED="0"

RUN \
    make cloudflared

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt

COPY --from=build_cloudflared /cloudflared/cloudflared /tmp/BUILDKIT/cloudflared

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/cloudflared"

FROM scratch

COPY --from=gpg_sign /tmp/BUILDKIT /

ENTRYPOINT ["/cloudflared"]
