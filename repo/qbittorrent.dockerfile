# Current Version: 1.0.4

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/68b1b131ba8f3193b700139961f8c2bb01826ee8/qbittorrent-nox-static.sh" | sed "s/http\:\/\/dl\-cdn/https\:\/\/dl\-cdn/g;s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" > "${WORKDIR}/qbittorrent-nox-static.sh"

FROM hezhijie0327/module:musl-boost AS BUILD_BOOST

FROM hezhijie0327/module:musl-iconv AS BUILD_ICONV

FROM hezhijie0327/module:musl-icu AS BUILD_ICU

FROM hezhijie0327/module:musl-libexecinfo AS BUILD_LIBEXECINFO

FROM hezhijie0327/module:musl-libtorrent AS BUILD_LIBTORRENT

FROM hezhijie0327/module:musl-ninja AS BUILD_NINJA

FROM hezhijie0327/module:musl-openssl AS BUILD_OPENSSL

FROM hezhijie0327/module:musl-qt AS BUILD_QT

FROM hezhijie0327/module:musl-zlibng AS BUILD_ZLIBNG

FROM hezhijie0327/base:alpine AS BUILD_QBITTORRENT

ENV qbt_build_tool="cmake" qbt_qt_version="6.2"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/qbittorrent-nox-static.sh /tmp/

COPY --from=BUILD_BOOST / /tmp/BUILDLIB/

COPY --from=BUILD_ICONV / /tmp/BUILDLIB/

COPY --from=BUILD_ICU / /tmp/BUILDLIB/

COPY --from=BUILD_LIBEXECINFO / /tmp/BUILDLIB/

COPY --from=BUILD_LIBTORRENT / /tmp/BUILDLIB/

COPY --from=BUILD_NINJA / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

COPY --from=BUILD_QT / /tmp/BUILDLIB/

COPY --from=BUILD_ZLIBNG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && cd "${WORKDIR}/BUILDLIB" && export qbt_cross_name=$(uname -m) && bash "${WORKDIR}/qbittorrent-nox-static.sh" qbittorrent --qbittorrent-master --strip -b "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}" && cp -rf "${WORKDIR}/BUILDLIB/completed/qbittorrent-nox" "${WORKDIR}/BUILDKIT/qbittorrent-nox"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_QBITTORRENT /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/qbittorrent-nox"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 51413/tcp 51413/udp 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
