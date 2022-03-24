# Current Version: 1.0.1

FROM alpine:edge as build

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && apk update && apk add bash curl && mkdir -p "${WORKDIR}/build" "${WORKDIR}/build/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/build/etc/ssl/certs/ca-certificates.crt" && export qbt_build_tool=cmake && export qbt_qt_version=6.2 && curl -sL "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh" | bash -s all --icu --libtorrent-master --qbittorrent-master --strip && cp -rf "${WORKDIR}/qbt-build/completed/qbittorrent-nox" "${WORKDIR}/build/qbittorrent-nox" && ${WORKDIR}/build/qbittorrent-nox --version

FROM scratch

COPY --from=build /tmp/build /

EXPOSE 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
