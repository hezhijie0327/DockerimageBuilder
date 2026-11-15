ARG NODEJS_VERSION="24"

ARG QBITTORRENT_VERSION=""
ARG VUETORRENT_VERSION=""
ARG PATCH_SHA="0000"

FROM alpine:latest AS get_info

ARG QBITTORRENT_VERSION
ARG VUETORRENT_VERSION
ARG PATCH_SHA

WORKDIR /tmp

COPY patches/qbittorrent /tmp/patches

RUN \
    apk add --no-cache curl git jq

RUN \
    export WORKDIR=$(pwd) \
    && export QBITTORRENT_VERSION=${QBITTORRENT_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/qbittorrent/qBittorrent/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/release-(?!.*(?:alpha|beta|rc))"))] | last // "" | sub("^refs/tags/release-"; "")' \
    )} \
    && export VUETORRENT_VERSION=${VUETORRENT_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/VueTorrent/VueTorrent/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/v"))] | last // "" | sub("^refs/tags/v"; "")' \
    )} \
    && [ -n "${QBITTORRENT_VERSION}" ] && [ -n "${VUETORRENT_VERSION}" ] \
    && echo "QBITTORRENT_VERSION=${QBITTORRENT_VERSION}" \
    && echo "VUETORRENT_VERSION=${VUETORRENT_VERSION}" \
    && git clone -b "master" --depth=1 "https://github.com/qbittorrent/qBittorrent.git" "${WORKDIR}/BUILDTMP/QBITTORRENT" \
    && git clone -b "master" --depth=1 "https://github.com/VueTorrent/VueTorrent.git" "${WORKDIR}/BUILDTMP/VUETORRENT" \
    && export QBITTORRENT_SHA=$(cd "${WORKDIR}/BUILDTMP/QBITTORRENT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export QBITTORRENT_CUSTOM_VERSION="-ZHIJIE-${QBITTORRENT_SHA}${PATCH_SHA}" \
    && export VUETORRENT_SHA=$(cd "${WORKDIR}/BUILDTMP/VUETORRENT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VUETORRENT_CUSTOM_VERSION="${VUETORRENT_VERSION}-ZHIJIE-${VUETORRENT_SHA}${PATCH_SHA}" \
    && cat "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" \
        | sed -e "s/#define QBT_VERSION_MAJOR [[:xdigit:]]\+/#define QBT_VERSION_MAJOR $(echo $QBITTORRENT_VERSION | cut -d '.' -f 1)/g" \
              -e "s/#define QBT_VERSION_MINOR [[:xdigit:]]\+/#define QBT_VERSION_MINOR $(echo $QBITTORRENT_VERSION | cut -d '.' -f 2)/g" \
              -e "s/#define QBT_VERSION_BUGFIX [[:xdigit:]]\+/#define QBT_VERSION_BUGFIX $(echo $QBITTORRENT_VERSION | cut -d '.' -f 3)/g" \
              -e "s/#define QBT_VERSION_BUILD [[:xdigit:]]\+/#define QBT_VERSION_BUILD $(TEMP_BUILD=$(echo $QBITTORRENT_VERSION | cut -d '.' -f 4) && echo ${TEMP_BUILD:-0})/g" \
        | sed "s/#define QBT_VERSION_STATUS \"\(alpha\|beta\)[[:xdigit:]]\+\"/#define QBT_VERSION_STATUS \"${QBITTORRENT_CUSTOM_VERSION}\"/g" \
        > "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" \
    && mv "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in.patch" "${WORKDIR}/BUILDTMP/QBITTORRENT/src/base/version.h.in" \
    && git config --global user.email "you@example.com" \
    && git config --global user.name "Your Name" \
    && cd "${WORKDIR}/BUILDTMP/QBITTORRENT" \
    && git add . \
    && git commit -m "Update qBittorrent version to ${QBITTORRENT_CUSTOM_VERSION}" \
    && git format-patch -1 -o "${WORKDIR}/BUILDTMP" \
    && cat ${WORKDIR}/BUILDTMP/0001-Update-qBittorrent-version-to-*.patch ${WORKDIR}/patches/*.patch \
        > "${WORKDIR}/patch" \
    && cd "${WORKDIR}/BUILDTMP/VUETORRENT" \
    && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${VUETORRENT_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/VUETORRENT/package.json" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" \
    && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt"

FROM node:${NODEJS_VERSION}-slim AS build_vuetorrent

WORKDIR /vuetorrent

COPY --from=get_info /tmp/BUILDTMP/VUETORRENT /vuetorrent

RUN \
    npm install --force \
    && npm run build

FROM alpine:latest AS build_qbittorrent

WORKDIR /qbittorrent

COPY --from=get_info /tmp/patch /qbittorrent/patches/qbittorrent/master/patch

ENV \
    qbt_build_dir="/qbittorrent" \
    qbt_legacy_mode="yes" \
    qbt_optimise_strip="yes" \
    qbt_skip_icu="no" \
    qbt_libtorrent_master_jamfile="yes" \
    qbt_libtorrent_tag="RC_2_0" \
    qbt_qbittorrent_tag="master" \
    qbt_openssl_tag="lts" \
    qbt_zlib_type="zlib-ng" \
    qbt_linker_mold="yes" \
    qbt_workflow_files="no" \
    set_qbt_mcm_url="userdocs/musl-cross-make"

RUN \
    apk update \
    && apk add --no-cache bash build-base \
    && wget https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbt-nox-static.bash \
    && bash ./qbt-nox-static.bash bootstrap_deps \
    && bash ./qbt-nox-static.bash --bootstrap-all \
    && bash ./qbt-nox-static.bash zlib \
    && bash ./qbt-nox-static.bash icu \
    && bash ./qbt-nox-static.bash openssl \
    && bash ./qbt-nox-static.bash boost \
    && bash ./qbt-nox-static.bash libtorrent \
    && bash ./qbt-nox-static.bash qtbase \
    && bash ./qbt-nox-static.bash qttools \
    && bash ./qbt-nox-static.bash qbittorrent

FROM scratch AS rebased_qbittorrent

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_vuetorrent /vuetorrent/vuetorrent /VueTorrent

COPY --from=build_qbittorrent /qbittorrent/completed/qbittorrent-nox /qbittorrent-nox

FROM scratch

COPY --from=rebased_qbittorrent / /

EXPOSE 8080/tcp 9000/tcp

ENTRYPOINT ["/qbittorrent-nox"]
