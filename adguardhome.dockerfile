# Current Version: 1.5.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.adguardhome" > "${WORKDIR}/adguardhome.json" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source" > "${WORKDIR}/adguardhome.source.autobuild" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch" > "${WORKDIR}/adguardhome.patch.autobuild" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" > "${WORKDIR}/adguardhome.version.autobuild"

FROM hezhijie0327/module:golang AS BUILD_GOLANG

FROM hezhijie0327/module:nodejs AS BUILD_NODEJS

FROM hezhijie0327/base:ubuntu AS BUILD_ADGUARDHOME

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/adguardhome.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && npm install -g npm yarn && git clone -b master --depth=1 $(cat "${WORKDIR}/adguardhome.source.autobuild") "${WORKDIR}/BUILDTMP/ADGUARDHOME" && git clone -b main --depth=1 $(cat "${WORKDIR}/adguardhome.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && export AGH_SHA=$(cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AGH_VERSION=$(cat "${WORKDIR}/adguardhome.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/PATCH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AGH_CUSTOM_VERSION="${AGH_VERSION}-ZHIJIE-${AGH_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" && cp -r "${WORKDIR}/BUILDTMP/PATCH/adguardhome/static/filters.json" "${WORKDIR}/BUILDTMP/ADGUARDHOME/client/src/helpers/filters/filters.json" && cp -r "${WORKDIR}/BUILDTMP/PATCH/adguardhome/static/zh-cn.json" "${WORKDIR}/BUILDTMP/ADGUARDHOME/client/src/__locales/zh-cn.json" && git apply --reject ${WORKDIR}/BUILDTMP/PATCH/adguardhome/*.patch && make -j 1 VERSION="${AGH_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/BUILDTMP/ADGUARDHOME/AdGuardHome" "${WORKDIR}/BUILDKIT/AdGuardHome" && "${WORKDIR}/BUILDKIT/AdGuardHome" --version

FROM scratch

COPY --from=BUILD_ADGUARDHOME /tmp/BUILDKIT /

EXPOSE 3000/tcp 3001/tcp 443/tcp 443/udp 53/tcp 53/udp 80/tcp 853/tcp 853/udp

ENTRYPOINT ["/AdGuardHome"]
