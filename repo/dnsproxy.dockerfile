# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.dnsproxy" > "${WORKDIR}/dnsproxy.json" && cat "${WORKDIR}/dnsproxy.json" | jq -Sr ".version" && cat "${WORKDIR}/dnsproxy.json" | jq -Sr ".source" > "${WORKDIR}/dnsproxy.source.autobuild" && cat "${WORKDIR}/dnsproxy.json" | jq -Sr ".source_branch" > "${WORKDIR}/dnsproxy.source_branch.autobuild" && cat "${WORKDIR}/dnsproxy.json" | jq -Sr ".patch" > "${WORKDIR}/dnsproxy.patch.autobuild" && cat "${WORKDIR}/dnsproxy.json" | jq -Sr ".patch_branch" > "${WORKDIR}/dnsproxy.patch_branch.autobuild" && cat "${WORKDIR}/dnsproxy.json" | jq -Sr ".version" > "${WORKDIR}/dnsproxy.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_DNSPROXY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/dnsproxy.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/dnsproxy.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/dnsproxy.source.autobuild") "${WORKDIR}/BUILDTMP/DNSPROXY" && git clone -b $(cat "${WORKDIR}/dnsproxy.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/dnsproxy.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && export DNSPROXY_SHA=$(cd "${WORKDIR}/BUILDTMP/DNSPROXY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export DNSPROXY_VERSION=$(cat "${WORKDIR}/dnsproxy.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/PATCH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export DNSPROXY_CUSTOM_VERSION="${DNSPROXY_VERSION}-ZHIJIE-${DNSPROXY_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/DNSPROXY" && make -j 1 VERSION="${DNSPROXY_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/BUILDTMP/DNSPROXY/dnsproxy" "${WORKDIR}/BUILDKIT/dnsproxy"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_DNSPROXY /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/dnsproxy"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 443/udp 53/tcp 53/udp 853/tcp 853/udp

ENTRYPOINT ["/dnsproxy"]
