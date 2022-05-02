# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.mosdns" > "${WORKDIR}/mosdns.json" && cat "${WORKDIR}/mosdns.json" | jq -Sr ".version" && cat "${WORKDIR}/mosdns.json" | jq -Sr ".source" > "${WORKDIR}/mosdns.source.autobuild" && cat "${WORKDIR}/mosdns.json" | jq -Sr ".patch" > "${WORKDIR}/mosdns.patch.autobuild" && cat "${WORKDIR}/mosdns.json" | jq -Sr ".version" > "${WORKDIR}/mosdns.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_MOSDNS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/mosdns.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b master --depth=1 $(cat "${WORKDIR}/mosdns.source.autobuild") "${WORKDIR}/BUILDTMP/MOSDNS" && git clone -b main --depth=1 $(cat "${WORKDIR}/mosdns.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && export MOSDNS_SHA=$(cd "${WORKDIR}/BUILDTMP/MOSDNS" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MOSDNS_VERSION=$(cat "${WORKDIR}/mosdns.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/PATCH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MOSDNS_CUSTOM_VERSION="${MOSDNS_VERSION}-ZHIJIE-${MOSDNS_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/MOSDNS" && go build -ldflags "-s -w -X main.version=${MOSDNS_CUSTOM_VERSION}" -trimpath -o mosdns && cp -rf "${WORKDIR}/BUILDTMP/MOSDNS/mosdns" "${WORKDIR}/BUILDKIT/mosdns" && "${WORKDIR}/BUILDKIT/mosdns" --version

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_MOSDNS /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/mosdns"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 53/tcp 53/udp 80/tcp 853/tcp

ENTRYPOINT ["/mosdns"]
