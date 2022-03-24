# Current Version: 1.4.6

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "${WORKDIR}/apt.tmp" && cat "${WORKDIR}/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf ${WORKDIR}/*.tmp && apt update && apt install -qy curl git jq make && mkdir -p "${WORKDIR}/build" "${WORKDIR}/build/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/build/etc/ssl/certs/ca-certificates.crt" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".adguardhome" > "${WORKDIR}/adguardhome.json" && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".binary.version" && export GOLANG=$(cat "${WORKDIR}/adguardhome.json" | jq -Sr ".binary.source.golang" | sed "s/{GOLANG_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/amd64/g") && export NODEJS=$(cat "${WORKDIR}/adguardhome.json" | jq -Sr ".binary.source.nodejs" | sed "s/{NODEJS_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/x64/g") && mkdir "${WORKDIR}/GOLANG" && cd "${WORKDIR}/GOLANG" && curl -Ls -o - "${GOLANG}" | tar zxvf - --strip-components=1 && cd "${WORKDIR}" && mkdir "${WORKDIR}/NODEJS" && cd "${WORKDIR}/NODEJS" && curl -Ls -o - "${NODEJS}" | tar zxvf - --strip-components=1 && cd "${WORKDIR}" && export PATH="${WORKDIR}/GOLANG/bin:${WORKDIR}/NODEJS/bin:${PATH}" && npm install -g npm yarn && git clone -b master --depth=1 $(cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source") && git clone -b main --depth=1 $(cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch") && export AGH_SHA=$(cd ./AdGuardHome && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AGH_VERSION=$(cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version") && export PATCH_SHA=$(cd "./Patch" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AGH_CUSTOM_VERSION="${AGH_VERSION}-ZHIJIE-${AGH_SHA}${PATCH_SHA}" && cd ./AdGuardHome && cp -r "../Patch/adguardhome/static/filters.json" "./client/src/helpers/filters/filters.json" && cp -r "../Patch/adguardhome/static/zh-cn.json" "./client/src/__locales/zh-cn.json" && git apply --reject ../Patch/adguardhome/*.patch && make -j 1 VERSION="${AGH_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/AdGuardHome/AdGuardHome" "${WORKDIR}/build/AdGuardHome" && "${WORKDIR}/build/AdGuardHome" --version

FROM scratch

COPY --from=build /tmp/build /

EXPOSE 3000/tcp 3001/tcp 443/tcp 443/udp 53/tcp 53/udp 80/tcp 853/tcp 853/udp

ENTRYPOINT ["/AdGuardHome"]
