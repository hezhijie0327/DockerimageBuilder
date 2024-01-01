# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.cloudflared" > "${WORKDIR}/cloudflared.json" && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".version" && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".source" > "${WORKDIR}/cloudflared.source.autobuild" && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".source_branch" > "${WORKDIR}/cloudflared.source_branch.autobuild" && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".patch" > "${WORKDIR}/cloudflared.patch.autobuild" && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".patch_branch" > "${WORKDIR}/cloudflared.patch_branch.autobuild" && cat "${WORKDIR}/cloudflared.json" | jq -Sr ".version" > "${WORKDIR}/cloudflared.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_CLOUDFLARED

WORKDIR /tmp

COPY --from=GET_INFO /tmp/cloudflared.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/cloudflared.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/cloudflared.source.autobuild") "${WORKDIR}/BUILDTMP/CLOUDFLARED" && git clone -b $(cat "${WORKDIR}/cloudflared.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/cloudflared.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export CLOUDFLARED_SHA=$(cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export CLOUDFLARED_VERSION=$(cat "${WORKDIR}/cloudflared.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export CLOUDFLARED_CUSTOM_VERSION="${CLOUDFLARED_VERSION}-ZHIJIE-${CLOUDFLARED_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" && sed -i "s/\$(shell git describe --tags --always --match \"\[0-9\]\[0-9\]\[0-9\]\[0-9\].\*.\*\")/${CLOUDFLARED_CUSTOM_VERSION}/g" "${WORKDIR}/BUILDTMP/CLOUDFLARED/Makefile" && go mod tidy && go get -u ./cmd/cloudflared && go mod download && go get -t github.com/cloudflare/cloudflared/carrier && go mod vendor && go mod edit -require=github.com/quic-go/quic-go@v0.40.1-0.20231203135336-87ef8ec48d55 && go mod tidy && go mod vendor && export CGO_ENABLED=0 && make cloudflared && cp -rf "${WORKDIR}/BUILDTMP/CLOUDFLARED/cloudflared" "${WORKDIR}/BUILDKIT/cloudflared"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_CLOUDFLARED /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/cloudflared"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/cloudflared"]
