# Current Version: 1.0.6

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.qbittorrent" > "${WORKDIR}/qbittorrent.json" && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".version" && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".source" > "${WORKDIR}/qbittorrent.source.autobuild" && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".source_branch" > "${WORKDIR}/qbittorrent.source_branch.autobuild" && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".patch" > "${WORKDIR}/qbittorrent.patch.autobuild" && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".patch_branch" > "${WORKDIR}/qbittorrent.patch_branch.autobuild" && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".version" > "${WORKDIR}/qbittorrent.version.autobuild" && mkdir -p "${WORKDIR}/BUILDTMP" && echo $(uname -m) > "${WORKDIR}/arch" && git clone -b $(cat "${WORKDIR}/qbittorrent.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/qbittorrent.source.autobuild") "${WORKDIR}/BUILDTMP/QBITTORRENT" && git clone -b $(cat "${WORKDIR}/qbittorrent.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/qbittorrent.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export QBITTORRENT_SHA=$(cd "${WORKDIR}/BUILDTMP/QBITTORRENT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export QBITTORRENT_VERSION=$(cat "${WORKDIR}/qbittorrent.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export QBITTORRENT_CUSTOM_VERSION="-ZHIJIE-${QBITTORRENT_SHA}${PATCH_SHA}" && cat "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" | sed "s/#define QBT_VERSION_MAJOR [[:xdigit:]]\+/#define QBT_VERSION_MAJOR $(echo $QBITTORRENT_VERSION | cut -d '.' -f 1)/g;s/#define QBT_VERSION_MINOR [[:xdigit:]]\+/#define QBT_VERSION_MINOR $(echo $QBITTORRENT_VERSION | cut -d '.' -f 2)/g;s/#define QBT_VERSION_BUGFIX [[:xdigit:]]\+/#define QBT_VERSION_BUGFIX $(echo $QBITTORRENT_VERSION | cut -d '.' -f 3)/g;s/#define QBT_VERSION_BUILD [[:xdigit:]]\+/#define QBT_VERSION_BUILD $(TEMP_BUILD=$(echo $QBITTORRENT_VERSION | cut -d '.' -f 4) && echo ${TEMP_BUILD:-0})/g" | sed "s/#define QBT_VERSION_STATUS \"\(alpha\|beta\)[[:xdigit:]]\+\"/#define QBT_VERSION_STATUS \"${QBITTORRENT_CUSTOM_VERSION}\"/g" > "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" && mv "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" && sed -i "s/#include <algorithm>/#include <algorithm>\n#include <cstdint>/g" "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/utils/number.cpp" && git config --global user.email "you@example.com" && git config --global user.name "Your Name" && cd "${WORKDIR}/BUILDTMP/QBITTORRENT" && git add . && git commit -m "Update qBittorrent version to ${QBITTORRENT_CUSTOM_VERSION}" && git format-patch -1 -o "${WORKDIR}/BUILDTMP" && mv ${WORKDIR}/BUILDTMP/0001-Update-qBittorrent-version-to-*.patch "${WORKDIR}/patch"

FROM --platform=linux/amd64 hezhijie0327/base:alpine AS BUILD_QBITTORRENT

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

COPY --from=GET_INFO /tmp/patch /tmp/BUILDLIB/patches/qbittorrent/master/patch

WORKDIR /tmp

ENV qbt_qt_version="6"

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export qbt_cross_name=$(cat "${WORKDIR}/BUILDTMP/arch") && wget https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh -O "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" && bash "${WORKDIR}/BUILDTMP/qbittorrent-nox-static.sh" -b "${WORKDIR}/BUILDLIB" all -i -lm -qm -s -bs-p && cd "${WORKDIR}" && cp -rf "${WORKDIR}/BUILDLIB/completed/qbittorrent-nox" "${WORKDIR}/BUILDKIT/qbittorrent-nox"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_QBITTORRENT /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/qbittorrent-nox"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 51413/tcp 51413/udp 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
