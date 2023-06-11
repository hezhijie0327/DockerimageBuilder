# Current Version: 1.0.1

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_CLOUDFLARED

WORKDIR /tmp

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b "master" --depth=1 "https://github.com/cloudflare/cloudflared" "${WORKDIR}/BUILDTMP/CLOUDFLARED" && cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" && go mod tidy && go get -u ./cmd/cloudflared && go mod download && go get -t github.com/cloudflare/cloudflared/carrier && go mod vendor && export CGO_ENABLED=0 && make cloudflared && cp -rf "${WORKDIR}/BUILDTMP/CLOUDFLARED/cloudflared" "${WORKDIR}/BUILDKIT/cloudflared"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_CLOUDFLARED /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/cloudflared"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/cloudflared"]
