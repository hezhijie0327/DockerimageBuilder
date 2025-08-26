# Current Version: 1.3.8

ARG NODEJS_VERSION="22"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

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
    && cat "/opt/package.json" | jq -Sr ".repo.vuetorrent" > "${WORKDIR}/vuetorrent.json" \
    && cat "${WORKDIR}/vuetorrent.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/vuetorrent.json" | jq -Sr ".source" > "${WORKDIR}/vuetorrent.source.autobuild" \
    && cat "${WORKDIR}/vuetorrent.json" | jq -Sr ".source_branch" > "${WORKDIR}/vuetorrent.source_branch.autobuild" \
    && cat "${WORKDIR}/vuetorrent.json" | jq -Sr ".patch" > "${WORKDIR}/vuetorrent.patch.autobuild" \
    && cat "${WORKDIR}/vuetorrent.json" | jq -Sr ".patch_branch" > "${WORKDIR}/vuetorrent.patch_branch.autobuild" \
    && cat "${WORKDIR}/vuetorrent.json" | jq -Sr ".version" > "${WORKDIR}/vuetorrent.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/qbittorrent.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/qbittorrent.source.autobuild") "${WORKDIR}/BUILDTMP/QBITTORRENT" \
    && git clone -b $(cat "${WORKDIR}/qbittorrent.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/qbittorrent.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/vuetorrent.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vuetorrent.source.autobuild") "${WORKDIR}/BUILDTMP/VUETORRENT" \
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

FROM node:${NODEJS_VERSION}-slim AS build_vuetorrent

WORKDIR /vuetorrent

COPY --from=get_info /tmp/BUILDTMP/VUETORRENT /vuetorrent

RUN \
    npm install \
    && npm run build

FROM alpine:latest AS build_qbittorrent

WORKDIR /qbittorrent

COPY --from=get_info /tmp/SYS_ARCH /qbittorrent/SYS_ARCH
COPY --from=get_info /tmp/patch /qbittorrent/patches/qbittorrent/master/patch

RUN \
    apk update \
    && apk add --no-cache bash \
    && export qbt_cross_name=$(cat "/qbittorrent/SYS_ARCH") \
    && wget https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/ba8fab01d2a2f9228df0593d287a644f9d5f42c5/qbittorrent-nox-static.sh \
    && bash ./qbittorrent-nox-static.sh all \
        --bootstrap-patches \
        --build-directory /qbittorrent \
        --libtorrent-master \
        --qbittorrent-master \
        --strip

FROM scratch AS rebased_qbittorrent

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_vuetorrent /vuetorrent/vuetorrent /VueTorrent

COPY --from=build_qbittorrent /qbittorrent/completed/qbittorrent-nox /qbittorrent-nox

FROM scratch

COPY --from=rebased_qbittorrent / /

EXPOSE 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
