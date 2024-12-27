# Current Version: 1.2.1

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" \
    && cat "/opt/package.json" | jq -Sr ".repo.qbittorrent" > "${WORKDIR}/qbittorrent.json" \
    && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".source" > "${WORKDIR}/qbittorrent.source.autobuild" \
    && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".source_branch" > "${WORKDIR}/qbittorrent.source_branch.autobuild" \
    && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".patch" > "${WORKDIR}/qbittorrent.patch.autobuild" \
    && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".patch_branch" > "${WORKDIR}/qbittorrent.patch_branch.autobuild" \
    && cat "${WORKDIR}/qbittorrent.json" | jq -Sr ".version" > "${WORKDIR}/qbittorrent.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/qbittorrent.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/qbittorrent.source.autobuild") "${WORKDIR}/BUILDTMP/QBITTORRENT" \
    && git clone -b $(cat "${WORKDIR}/qbittorrent.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/qbittorrent.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export QBITTORRENT_SHA=$(cd "${WORKDIR}/BUILDTMP/QBITTORRENT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export QBITTORRENT_VERSION=$(cat "${WORKDIR}/qbittorrent.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export QBITTORRENT_CUSTOM_VERSION="-ZHIJIE-${QBITTORRENT_SHA}${PATCH_SHA}" \
    && cat "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" | sed "s/#define QBT_VERSION_MAJOR [[:xdigit:]]\+/#define QBT_VERSION_MAJOR $(echo $QBITTORRENT_VERSION | cut -d '.' -f 1)/g;s/#define QBT_VERSION_MINOR [[:xdigit:]]\+/#define QBT_VERSION_MINOR $(echo $QBITTORRENT_VERSION | cut -d '.' -f 2)/g;s/#define QBT_VERSION_BUGFIX [[:xdigit:]]\+/#define QBT_VERSION_BUGFIX $(echo $QBITTORRENT_VERSION | cut -d '.' -f 3)/g;s/#define QBT_VERSION_BUILD [[:xdigit:]]\+/#define QBT_VERSION_BUILD $(TEMP_BUILD=$(echo $QBITTORRENT_VERSION | cut -d '.' -f 4) && echo ${TEMP_BUILD:-0})/g" | sed "s/#define QBT_VERSION_STATUS \"\(alpha\|beta\)[[:xdigit:]]\+\"/#define QBT_VERSION_STATUS \"${QBITTORRENT_CUSTOM_VERSION}\"/g" > "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" \
    && mv "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" \
    && git config --global user.email "you@example.com" \
    && git config --global user.name "Your Name" \
    && cd "${WORKDIR}/BUILDTMP/QBITTORRENT" \
    && git add . \
    && git commit -m "Update qBittorrent version to ${QBITTORRENT_CUSTOM_VERSION}" \
    && git format-patch -1 -o "${WORKDIR}/BUILDTMP" \
    && cat ${WORKDIR}/BUILDTMP/0001-Update-qBittorrent-version-to-*.patch ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/qbittorrent/*.patch > "${WORKDIR}/patch" \
    && echo $(uname -m) > "${WORKDIR}/SYS_ARCH"

FROM --platform=linux/amd64 alpine:latest AS build_qbittorrent

WORKDIR /qbittorrent

COPY --from=get_info /tmp/SYS_ARCH /qbittorrent/SYS_ARCH
COPY --from=get_info /tmp/patch /qbittorrent/patches/qbittorrent/master/patch

ENV qbt_qt_version="6"

RUN \
    apk update \
    && apk add --no-cache bash \
    && export qbt_cross_name=$(cat "/qbittorrent/SYS_ARCH") \
    && wget https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbittorrent-nox-static.sh \
    && bash ./qbittorrent-nox-static.sh -b /qbittorrent all -i -lm -qm -s -bs-p

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt

COPY --from=build_qbittorrent /qbittorrent/completed/qbittorrent-nox /tmp/BUILDKIT/qbittorrent-nox

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/qbittorrent-nox"

FROM scratch

COPY --from=gpg_sign /tmp/BUILDKIT /

EXPOSE 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
