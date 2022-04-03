# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh" | sed "s/http\:\/\/dl\-cdn/https\:\/\/dl\-cdn/g;s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" > "${WORKDIR}/qbittorrent-nox-static.sh"

FROM hezhijie0327/module:musl-boost AS BUILD_BOOST

FROM hezhijie0327/module:musl-ninja AS BUILD_NINJA

FROM hezhijie0327/module:musl-openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:alpine AS BUILD_LIBTORRENT

ENV libtorrent_version="2.0" qbt_build_tool="cmake"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/qbittorrent-nox-static.sh /tmp/

COPY --from=BUILD_BOOST / /tmp/BUILDLIB/

COPY --from=BUILD_NINJA / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}/BUILDLIB" && export qbt_cross_name=$(uname -m) && bash "${WORKDIR}/qbittorrent-nox-static.sh" libtorrent --libtorrent-master -b "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}" && rm -rf "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl.tar.gz" "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl" ${WORKDIR}/BUILDLIB/bin/${qbt_cross_name}-linux-musl-* "${WORKDIR}/BUILDLIB/lib/bfd-plugins" "${WORKDIR}/BUILDLIB/lib/gcc" "${WORKDIR}/BUILDLIB/libexec/gcc" ${WORKDIR}/BUILDLIB/share/gcc-* "${WORKDIR}/BUILDLIB/share/locale" "${WORKDIR}/BUILDLIB/share/man"

FROM scratch

COPY --from=BUILD_LIBTORRENT /tmp/BUILDLIB /
