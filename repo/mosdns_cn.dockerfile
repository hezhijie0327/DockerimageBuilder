# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.mosdns_cn" > "${WORKDIR}/mosdns_cn.json" && cat "${WORKDIR}/mosdns_cn.json" | jq -Sr ".version" && cat "${WORKDIR}/mosdns_cn.json" | jq -Sr ".source" > "${WORKDIR}/mosdns_cn.source.autobuild" && cat "${WORKDIR}/mosdns_cn.json" | jq -Sr ".source_branch" > "${WORKDIR}/mosdns_cn.source_branch.autobuild" && cat "${WORKDIR}/mosdns_cn.json" | jq -Sr ".patch" > "${WORKDIR}/mosdns_cn.patch.autobuild" && cat "${WORKDIR}/mosdns_cn.json" | jq -Sr ".patch_branch" > "${WORKDIR}/mosdns_cn.patch_branch.autobuild" && cat "${WORKDIR}/mosdns_cn.json" | jq -Sr ".version" > "${WORKDIR}/mosdns_cn.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_MOSDNS_CN

ENV CGO_ENABLED="0"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/mosdns_cn.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/mosdns_cn.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/mosdns_cn.source.autobuild") "${WORKDIR}/BUILDTMP/MOSDNS_CN" && git clone -b $(cat "${WORKDIR}/mosdns_cn.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/mosdns_cn.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && export MOSDNS_CN_SHA=$(cd "${WORKDIR}/BUILDTMP/MOSDNS_CN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MOSDNS_CN_VERSION=$(cat "${WORKDIR}/mosdns_cn.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/PATCH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MOSDNS_CN_CUSTOM_VERSION="${MOSDNS_CN_VERSION}-ZHIJIE-${MOSDNS_CN_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/MOSDNS_CN" && go build -ldflags "-s -w -X main.version=${MOSDNS_CN_CUSTOM_VERSION}" -trimpath -o mosdns-cn && cp -rf "${WORKDIR}/BUILDTMP/MOSDNS_CN/mosdns-cn" "${WORKDIR}/BUILDKIT/mosdns-cn" && "${WORKDIR}/BUILDKIT/mosdns-cn" --version

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_MOSDNS_CN /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/mosdns-cn"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 53/tcp 53/udp 80/tcp 853/tcp

ENTRYPOINT ["/mosdns-cn"]
