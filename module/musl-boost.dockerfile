# Current Version: 1.0.4

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh" | sed "s/aarch64-linux-musl/aarch64-alpine-linux-musl/g;s/x86_64-linux-musl/x86_64-alpine-linux-musl/g;s/\${qbt_cross_host}-ar/\${qbt_cross_host}-gcc-ar/g;s/http\:\/\/dl\-cdn/https\:\/\/dl\-cdn/g;s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" > "${WORKDIR}/qbittorrent-nox-static.sh"

FROM hezhijie0327/module:musl-icu AS BUILD_ICU

FROM hezhijie0327/base:alpine AS BUILD_BOOST

WORKDIR /tmp

COPY --from=GET_INFO /tmp/qbittorrent-nox-static.sh /tmp/

COPY --from=BUILD_ICU / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" && find "${WORKDIR}/BUILDLIB" -print > "${WORKDIR}/cleanup.list.autobuild" && echo '#!/bin/bash' > "${WORKDIR}/cleanup.sh.autobuild" && echo "FILE_LIST=(\$(cat ${WORKDIR}/cleanup.list.autobuild | awk '{print \$1}')) && for FILE_LIST_TASK in \"\${!FILE_LIST[@]}\"; do rm \"\${FILE_LIST[\$FILE_LIST_TASK]}\" > \"/dev/null\" 2>&1; done" >> "${WORKDIR}/cleanup.sh.autobuild" && cd "${WORKDIR}/BUILDLIB" && export qbt_cross_name=$(uname -m) && export qbt_skip_icu="no" && bash "${WORKDIR}/qbittorrent-nox-static.sh" boost -b "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}" && rm -rf "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl.tar.gz" "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl" ${WORKDIR}/BUILDLIB/bin/${qbt_cross_name}-linux-musl-* "${WORKDIR}/BUILDLIB/completed" "${WORKDIR}/BUILDLIB/graphs" "${WORKDIR}/BUILDLIB/lib/bfd-plugins" "${WORKDIR}/BUILDLIB/lib/gcc" "${WORKDIR}/BUILDLIB/libexec/gcc" "${WORKDIR}/BUILDLIB/logs" ${WORKDIR}/BUILDLIB/share/gcc-* "${WORKDIR}/BUILDLIB/share/locale" "${WORKDIR}/BUILDLIB/share/man" "${WORKDIR}/BUILDLIB/user-config.jam" "${WORKDIR}/BUILDLIB/boost.tar.gz" && bash "${WORKDIR}/cleanup.sh.autobuild" && for i in {1..10}; do find "${WORKDIR}/BUILDLIB" -type d -empty -delete; done

FROM scratch

COPY --from=BUILD_BOOST /tmp/BUILDLIB /
