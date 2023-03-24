# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh" | sed "s/aarch64-linux-musl/aarch64-alpine-linux-musl/g;s/x86_64-linux-musl/x86_64-alpine-linux-musl/g;s/\${qbt_cross_host}-ar/\${qbt_cross_host}-gcc-ar/g;s/http\:\/\/dl\-cdn/https\:\/\/dl\-cdn/g;s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" > "${WORKDIR}/qbittorrent-nox-static.sh"

FROM hezhijie0327/base:alpine AS BUILD_NINJA

ENV qbt_build_tool="cmake" qbt_qt_version="6"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/qbittorrent-nox-static.sh /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}/BUILDLIB" && apk update && export qbt_cross_name=$(uname -m) && bash "${WORKDIR}/qbittorrent-nox-static.sh" double_conversion -b "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}" && rm -rf "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl.tar.gz" "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl" ${WORKDIR}/BUILDLIB/bin/${qbt_cross_name}-linux-musl-* "${WORKDIR}/BUILDLIB/completed" "${WORKDIR}/BUILDLIB/graphs" "${WORKDIR}/BUILDLIB/lib/bfd-plugins" "${WORKDIR}/BUILDLIB/lib/gcc" "${WORKDIR}/BUILDLIB/libexec/gcc" "${WORKDIR}/BUILDLIB/logs" ${WORKDIR}/BUILDLIB/share/gcc-* "${WORKDIR}/BUILDLIB/share/locale" "${WORKDIR}/BUILDLIB/share/man" "${WORKDIR}/BUILDLIB/user-config.jam" ${WORKDIR}/BUILDLIB/*.apk && for i in {1..10}; do find "${WORKDIR}/BUILDLIB" -type d -empty -delete; done

FROM scratch

COPY --from=BUILD_NINJA /tmp/BUILDLIB /
