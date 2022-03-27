# Current Version: 1.5.0

FROM alpine:latest AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && apk update && apk add curl jq && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".adguardhome" > "${WORKDIR}/adguardhome.json" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".binary.version" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".binary.source.golang" | sed "s/{GOLANG_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/amd64/g" > "${WORKDIR}/golang.autobuild" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".binary.source.nodejs" | sed "s/{NODEJS_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/x64/g" > "${WORKDIR}/nodejs.autobuild" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source" > "${WORKDIR}/adguardhome.source.autobuild" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch" > "${WORKDIR}/adguardhome.patch.autobuild" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" > "${WORKDIR}/adguardhome.version.autobuild"

FROM alpine:latest AS BUILD_GOLANG

WORKDIR /tmp

COPY --from=GET_INFO /tmp/golang.autobuild /tmp/

RUN export WORKDIR=$(pwd) && apk update && apk add curl && mkdir -p "${WORKDIR}/BUILDLIB/GOLANG" && cd "${WORKDIR}/BUILDLIB/GOLANG" && curl -Ls -o - $(cat "${WORKDIR}/golang.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM alpine:latest AS BUILD_NODEJS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/nodejs.autobuild /tmp/

RUN export WORKDIR=$(pwd) && apk update && apk add curl && mkdir -p "${WORKDIR}/BUILDLIB/NODEJS" && cd "${WORKDIR}/BUILDLIB/NODEJS" && curl -Ls -o - $(cat "${WORKDIR}/nodejs.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM ubuntu:devel AS BUILD_ADGUARDHOME

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/adguardhome.*.autobuild /tmp/

COPY --from=BUILD_GOLANG /tmp/BUILDLIB/GOLANG /tmp/BUILDLIB/GOLANG/

COPY --from=BUILD_NODEJS /tmp/BUILDLIB/NODEJS /tmp/BUILDLIB/NODEJS/

RUN export WORKDIR=$(pwd) && cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "${WORKDIR}/apt.tmp" && cat "${WORKDIR}/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf ${WORKDIR}/*.tmp && apt update && apt install -qy git make && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PATH="${WORKDIR}/BUILDLIB/GOLANG/bin:${WORKDIR}/BUILDLIB/NODEJS/bin:${PATH}" && npm install -g npm yarn && git clone -b master --depth=1 $(cat "${WORKDIR}/adguardhome.source.autobuild") "${WORKDIR}/BUILDTMP/ADGUARDHOME" && git clone -b main --depth=1 $(cat "${WORKDIR}/adguardhome.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && export AGH_SHA=$(cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AGH_VERSION=$(cat "${WORKDIR}/adguardhome.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/PATCH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AGH_CUSTOM_VERSION="${AGH_VERSION}-ZHIJIE-${AGH_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" && cp -r "${WORKDIR}/BUILDTMP/PATCH/adguardhome/static/filters.json" "${WORKDIR}/BUILDTMP/ADGUARDHOME/client/src/helpers/filters/filters.json" && cp -r "${WORKDIR}/BUILDTMP/PATCH/adguardhome/static/zh-cn.json" "${WORKDIR}/BUILDTMP/ADGUARDHOME/client/src/__locales/zh-cn.json" && git apply --reject ${WORKDIR}/BUILDTMP/PATCH/adguardhome/*.patch && make -j 1 VERSION="${AGH_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/BUILDTMP/ADGUARDHOME/AdGuardHome" "${WORKDIR}/BUILDKIT/AdGuardHome" && "${WORKDIR}/BUILDKIT/AdGuardHome" --version

FROM scratch

COPY --from=BUILD_ADGUARDHOME /tmp/BUILDKIT /

EXPOSE 3000/tcp 3001/tcp 443/tcp 443/udp 53/tcp 53/udp 80/tcp 853/tcp 853/udp

ENTRYPOINT ["/AdGuardHome"]
