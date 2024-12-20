# Current Version: 2.1.7

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.adguardhome" > "${WORKDIR}/adguardhome.json" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source" > "${WORKDIR}/adguardhome.source.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source_branch" > "${WORKDIR}/adguardhome.source_branch.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch" > "${WORKDIR}/adguardhome.patch.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch_branch" > "${WORKDIR}/adguardhome.patch_branch.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" > "${WORKDIR}/adguardhome.version.autobuild"

FROM hezhijie0327/module:golang AS BUILD_GOLANG

FROM hezhijie0327/module:nodejs AS BUILD_NODEJS

FROM hezhijie0327/base:ubuntu AS BUILD_ADGUARDHOME

WORKDIR /tmp

COPY --from=GET_INFO /tmp/adguardhome.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" \
    && git clone -b $(cat "${WORKDIR}/adguardhome.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/adguardhome.source.autobuild") "${WORKDIR}/BUILDTMP/ADGUARDHOME" \
    && git clone -b $(cat "${WORKDIR}/adguardhome.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/adguardhome.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export AGH_SHA=$(cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export AGH_VERSION=$(cat "${WORKDIR}/adguardhome.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export AGH_CUSTOM_VERSION="${AGH_VERSION}-ZHIJIE-${AGH_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/adguardhome/*.patch \
    && cp -r "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/adguardhome/static/zh-cn.json" "${WORKDIR}/BUILDTMP/ADGUARDHOME/client/src/__locales/zh-cn.json" \
    && export NODE_OPTIONS=--openssl-legacy-provider \
    && npm install -g npm yarn \
    && make -j 1 VERSION="${AGH_CUSTOM_VERSION}" \
    && cp -rf "${WORKDIR}/BUILDTMP/ADGUARDHOME/AdGuardHome" "${WORKDIR}/BUILDKIT/AdGuardHome"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_ADGUARDHOME /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/AdGuardHome"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 3000/tcp 443/tcp 443/udp 53/tcp 53/udp 6060/tcp 67/udp 68/udp 80/tcp 853/tcp 853/udp

ENTRYPOINT ["/AdGuardHome"]
