# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" && echo $(uname -m) > "${WORKDIR}/arch" && git clone -b "master" --depth=1 "https://github.com/qbittorrent/qBittorrent.git" "${WORKDIR}/BUILDTMP/QBITTORRENT" && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export QBITTORRENT_SHA=$(cd "${WORKDIR}/BUILDTMP/QBITTORRENT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export QBITTORRENT_CUSTOM_VERSION="-ZHIJIE-${QBITTORRENT_SHA}${PATCH_SHA}" && cat "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" | sed "s/#define QBT_VERSION_STATUS \"\(alpha\|beta\)[[:digit:]]\+\"/#define QBT_VERSION_STATUS \"${QBITTORRENT_CUSTOM_VERSION}\"/g" > "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" && mv "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" && git config --global user.email "you@example.com" && git config --global user.name "Your Name" && cd "${WORKDIR}/BUILDTMP/QBITTORRENT" && git add . && git commit -m "Update qBittorrent version to ${QBITTORRENT_CUSTOM_VERSION}" && git format-patch -1 -o "${WORKDIR}/BUILDTMP" && mv ${WORKDIR}/BUILDTMP/0001-Update-qBittorrent-version-to-*.patch "${WORKDIR}/patch"

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_QBITTORRENT

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

COPY --from=GET_INFO /tmp/patch /tmp/BUILDLIB/patches/qbittorrent/master/patch

WORKDIR /tmp

ENV qbt_qt_version="6"

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export qbt_cross_name=$(cat "${WORKDIR}/BUILDTMP/arch") && wget https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh -O "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" && sed -i "s/jammy/$(cat '/etc/os-release' | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g')/g" "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" && bash "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" -b "${WORKDIR}/BUILDLIB" all -i -lm -qm -s -bs-p && cd "${WORKDIR}" && cp -rf "${WORKDIR}/BUILDLIB/completed/qbittorrent-nox" "${WORKDIR}/BUILDKIT/qbittorrent-nox"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_QBITTORRENT /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/qbittorrent-nox"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 51413/tcp 51413/udp 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
