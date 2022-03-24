# Current Version: 1.0.0

FROM ubuntu:latest as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "${WORKDIR}/apt.tmp" && cat "${WORKDIR}/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf ${WORKDIR}/*.tmp && apt update && apt install -yq curl && mkdir -p "${WORKDIR}/build" "${WORKDIR}/build/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/build/etc/ssl/certs/ca-certificates.crt" && curl -sL "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh" | bash -s all --icu --qbittorrent-master --strip && cp -rf "${WORKDIR}/qbt-build/completed/qbittorrent-nox" "${WORKDIR}/build/qbittorrent-nox" && ${WORKDIR}/build/qbittorrent-nox --version

FROM scratch

COPY --from=build /tmp/build /

EXPOSE 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
