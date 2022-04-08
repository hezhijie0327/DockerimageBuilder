# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh" | sed "s/http\:\/\/dl\-cdn/https\:\/\/dl\-cdn/g;s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" > "${WORKDIR}/qbittorrent-nox-static.sh"

FROM hezhijie0327/module:musl-icu AS BUILD_ICU

FROM hezhijie0327/base:alpine AS BUILD_BOOST

WORKDIR /tmp

COPY --from=GET_INFO /tmp/qbittorrent-nox-static.sh /tmp/

COPY --from=BUILD_ICU / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" && find "${WORKDIR}/BUILDLIB" -print > "${WORKDIR}/cleanup.list.autobuild" && echo '#!/bin/bash' > "${WORKDIR}/cleanup.sh.autobuild" && echo "FILE_LIST=(\$(cat ${WORKDIR}/cleanup.list.autobuild | awk '{print \$1}')) && for FILE_LIST_TASK in \"\${!FILE_LIST[@]}\"; do rm \"\${FILE_LIST[\$FILE_LIST_TASK]}\" > \"/dev/null\" 2>&1; done" >> "${WORKDIR}/cleanup.sh.autobuild" && cd "${WORKDIR}/BUILDLIB" && export qbt_cross_name=$(uname -m) && bash "${WORKDIR}/qbittorrent-nox-static.sh" boost -b "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}" && rm -rf "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl.tar.gz" "${WORKDIR}/BUILDLIB/${qbt_cross_name}-linux-musl" ${WORKDIR}/BUILDLIB/bin/${qbt_cross_name}-linux-musl-* "${WORKDIR}/BUILDLIB/completed" "${WORKDIR}/BUILDLIB/graphs" "${WORKDIR}/BUILDLIB/lib/bfd-plugins" "${WORKDIR}/BUILDLIB/lib/gcc" "${WORKDIR}/BUILDLIB/libexec/gcc" "${WORKDIR}/BUILDLIB/logs" ${WORKDIR}/BUILDLIB/share/gcc-* "${WORKDIR}/BUILDLIB/share/locale" "${WORKDIR}/BUILDLIB/share/man" "${WORKDIR}/BUILDLIB/user-config.jam" "${WORKDIR}/BUILDLIB/boost.tar.gz" && bash "${WORKDIR}/cleanup.sh.autobuild" && for i in {1..10}; do find "${WORKDIR}/BUILDLIB" -type d -empty -delete; done

FROM scratch

COPY --from=BUILD_BOOST /tmp/BUILDLIB /
