# Current Version: 2.2.1

ARG GOLANG_VERSION="1"
ARG NODEJS_VERSION="22"

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.adguardhome" > "${WORKDIR}/adguardhome.json" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source" > "${WORKDIR}/adguardhome.source.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".source_branch" > "${WORKDIR}/adguardhome.source_branch.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch" > "${WORKDIR}/adguardhome.patch.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".patch_branch" > "${WORKDIR}/adguardhome.patch_branch.autobuild" \
    && cat "${WORKDIR}/adguardhome.json" | jq -Sr ".version" > "${WORKDIR}/adguardhome.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/adguardhome.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/adguardhome.source.autobuild") "${WORKDIR}/BUILDTMP/ADGUARDHOME" \
    && git clone -b $(cat "${WORKDIR}/adguardhome.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/adguardhome.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export ADGUARDHOME_SHA=$(cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export ADGUARDHOME_VERSION=$(cat "${WORKDIR}/adguardhome.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export ADGUARDHOME_CUSTOM_VERSION="${ADGUARDHOME_VERSION}-ZHIJIE-${ADGUARDHOME_SHA}${PATCH_SHA}" \
    && echo "${ADGUARDHOME_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/ADGUARDHOME/ADGUARDHOME_CUSTOM_VERSION" \
    && cd "${WORKDIR}/BUILDTMP/ADGUARDHOME" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/adguardhome/*.patch \
    && cp -r "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/adguardhome/static/zh-cn.json" "${WORKDIR}/BUILDTMP/ADGUARDHOME/client/src/__locales/zh-cn.json"

FROM node:${NODEJS_VERSION}-slim AS build_adguardhome_web

WORKDIR /adguardhome

COPY --from=get_info /tmp/BUILDTMP/ADGUARDHOME /adguardhome

ENV \
    NODE_OPTIONS="--openssl-legacy-provider" \
    NPM_FLAGS="--prefix client" \
    NPM_INSTALL_FLAGS="--quiet --no-progress --ignore-engines --ignore-optional --ignore-platform --ignore-scripts"

RUN \
    apt update \
    && apt install make -qy \
    && make js-deps \
    && make js-build

FROM golang:${GOLANG_VERSION} AS build_adguardhome

WORKDIR /adguardhome

COPY --from=build_adguardhome_web /adguardhome /adguardhome

RUN \
    make go-deps \
    && make go-build VERSION="$(cat /adguardhome/ADGUARDHOME_CUSTOM_VERSION)"

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt

COPY --from=build_adguardhome /adguardhome/AdGuardHome /tmp/BUILDKIT/AdGuardHome

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/AdGuardHome"

FROM scratch

COPY --from=gpg_sign /tmp/BUILDKIT /

EXPOSE 3000/tcp 443/tcp 443/udp 53/tcp 53/udp 6060/tcp 67/udp 68/udp 80/tcp 853/tcp 853/udp

ENTRYPOINT ["/AdGuardHome"]
