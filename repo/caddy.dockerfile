# Current Version: 1.1.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.caddy" > "${WORKDIR}/caddy.json" && cat "${WORKDIR}/caddy.json" | jq -Sr ".version" && cat "${WORKDIR}/caddy.json" | jq -Sr ".source" > "${WORKDIR}/caddy.source.autobuild" && cat "${WORKDIR}/caddy.json" | jq -Sr ".source_branch" > "${WORKDIR}/caddy.source_branch.autobuild" && cat "${WORKDIR}/caddy.json" | jq -Sr ".patch" > "${WORKDIR}/caddy.patch.autobuild" && cat "${WORKDIR}/caddy.json" | jq -Sr ".patch_branch" > "${WORKDIR}/caddy.patch_branch.autobuild" && cat "${WORKDIR}/caddy.json" | jq -Sr ".version" > "${WORKDIR}/caddy.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_CADDY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/caddy.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/caddy.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/caddy.source.autobuild") "${WORKDIR}/BUILDTMP/CADDY" && git clone -b $(cat "${WORKDIR}/caddy.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/caddy.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export CADDY_SHA=$(cd "${WORKDIR}/BUILDTMP/CADDY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export CADDY_VERSION=$(cat "${WORKDIR}/caddy.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export CADDY_CUSTOM_VERSION="${CADDY_VERSION}-ZHIJIE-${CADDY_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/CADDY/cmd/caddy" && export CGO_ENABLED=0 && go build -ldflags "-X github.com/caddyserver/caddy/v2.CustomVersion=${CADDY_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/BUILDTMP/CADDY/cmd/caddy/caddy" "${WORKDIR}/BUILDKIT/caddy"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_caddy /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/caddy"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 443/udp 80/tcp

ENTRYPOINT ["/caddy"]
