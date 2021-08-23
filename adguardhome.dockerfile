# Current Version: 1.2.5

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf /tmp/* && apt update && apt upgrade -qy && apt dist-upgrade -qy && apt autoremove -qy && apt install -qy curl git jq make && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".adguardhome" > "/tmp/adguardhome.json" && export GOLANG="$(cat '/tmp/adguardhome.json' | jq -Sr .binary.$(uname -m).golang)" && export NODEJS="$(cat '/tmp/adguardhome.json' | jq -Sr .binary.$(uname -m).nodejs)" && export WORKDIR=$(pwd) && mkdir "${WORKDIR}/GOLANG" && cd "${WORKDIR}/GOLANG" && curl -Ls -o - "${GOLANG}" | tar zxvf - --strip-components=1 && cd "${WORKDIR}" && mkdir "${WORKDIR}/NODEJS" && cd "${WORKDIR}/NODEJS" && curl -Ls -o - "${NODEJS}" | tar zxvf - --strip-components=1 && cd "${WORKDIR}" && export PATH="${WORKDIR}/GOLANG/bin:${WORKDIR}/NODEJS/bin:${PATH}" && npm install -g yarn && git clone -b master "$(cat '/tmp/adguardhome.json' | jq -Sr '.source')" && git clone -b main --depth=1 "$(cat '/tmp/adguardhome.json' | jq -Sr '.patch')" && AGH_SHA=$(cd ./AdGuardHome && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && AGH_VERSION=$(cd ./AdGuardHome && git describe --abbrev=0 | sed "s/\-.*//g;s/v//g") && PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && AGH_CUSTOM_VERSION="${AGH_VERSION}-ZHIJIE-${AGH_SHA}${PATCH_SHA}" && cd ./AdGuardHome && cp -r "../Patch/adguardhome/static/filters.json" "./client/src/helpers/filters/filters.json" && cp -r "../Patch/adguardhome/static/zh-cn.json" "./client/src/__locales/zh-cn.json" && git apply --reject ../Patch/adguardhome/*.patch && make -j 1 VERSION="${AGH_CUSTOM_VERSION}"

FROM alpine:latest

WORKDIR /etc

COPY --from=build /tmp/AdGuardHome/AdGuardHome /usr/local/bin/adguardhome

RUN mkdir "/etc/adguardhome" "/etc/adguardhome/cert" "/etc/adguardhome/conf" "/etc/adguardhome/work" && /usr/local/bin/adguardhome --version

WORKDIR /etc/adguardhome

EXPOSE 3000/tcp 3001/tcp 443/tcp 443/udp 53/tcp 53/udp 5443/tcp 5443/udp 80/tcp 853/tcp 8853/udp

VOLUME ["/etc/adguardhome/cert", "/etc/adguardhome/conf", "/etc/adguardhome/work"]

ENTRYPOINT ["/usr/local/bin/adguardhome"]
