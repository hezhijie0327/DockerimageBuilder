# Current Version: 1.0.0

FROM ubuntu:latest AS GET_ARCH

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && echo $(uname -m) > "${WORKDIR}/arch"

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_QBITTORRENT

COPY --from=GET_ARCH /tmp/arch /tmp/BUILDTMP/arch

WORKDIR /tmp

ENV qbt_qt_version="6"

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export qbt_cross_name=$(cat "${WORKDIR}/BUILDTMP/arch") && wget https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh -O "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" && sed -i "s/jammy/$(cat '/etc/os-release' | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g')/g" "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" && bash "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" -b "${WORKDIR}/BUILDLIB" -i -lm -qm -s all && cd "${WORKDIR}" && cp -rf "${WORKDIR}/BUILDLIB/completed/qbittorrent-nox" "${WORKDIR}/BUILDKIT/qbittorrent-nox"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_QBITTORRENT /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/qbittorrent-nox"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 51413/tcp 51413/udp 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
