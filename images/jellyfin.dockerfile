ARG DOTNET_VERSION="10.0"
ARG NODEJS_VERSION="24"

ARG JELLYFIN_VERSION=""
ARG JELLYFIN_WEB_VERSION=""
ARG PATCH_SHA="0000"

FROM alpine:latest AS get_info

ARG JELLYFIN_VERSION
ARG JELLYFIN_WEB_VERSION
ARG PATCH_SHA

WORKDIR /tmp

RUN \
    apk add --no-cache curl git gnupg jq

RUN \
    export WORKDIR=$(pwd) \
    && export JELLYFIN_VERSION=${JELLYFIN_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/v(?!.*-)"))] | last // "" | sub("^refs/tags/v"; "")' \
    )} \
    && export JELLYFIN_WEB_VERSION=${JELLYFIN_WEB_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin-web/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/v(?!.*-)"))] | last // "" | sub("^refs/tags/v"; "")' \
    )} \
    && [ -n "${JELLYFIN_VERSION}" ] && [ -n "${JELLYFIN_WEB_VERSION}" ] \
    && echo "JELLYFIN_VERSION=${JELLYFIN_VERSION}" \
    && echo "JELLYFIN_WEB_VERSION=${JELLYFIN_WEB_VERSION}" \
    && git clone -b "master" --depth=1 "https://github.com/jellyfin/jellyfin.git" "${WORKDIR}/BUILDTMP/JELLYFIN" \
    && git clone -b "master" --depth=1 "https://github.com/jellyfin/jellyfin-web.git" "${WORKDIR}/BUILDTMP/JELLYFIN_WEB" \
    && export JELLYFIN_SHA=$(cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export JELLYFIN_CUSTOM_VERSION="${JELLYFIN_VERSION}-ZHIJIE-${JELLYFIN_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/JELLYFIN" \
    && git submodule update --init --depth=1 \
    && cd "${WORKDIR}/BUILDTMP/JELLYFIN_WEB" \
    && sed -i \
        "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${JELLYFIN_CUSTOM_VERSION}\"/g" \
        "${WORKDIR}/BUILDTMP/JELLYFIN_WEB/package.json" \
    && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") \
        > "${WORKDIR}/BUILDTMP/JELLYFIN/SYS_ARCH" \
    && curl -s --connect-timeout 15 "https://repo.jellyfin.org/jellyfin_team.gpg.key" \
        | gpg --dearmor > "${WORKDIR}/BUILDTMP/JELLYFIN/jellyfin-archive-keyring.gpg" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" \
    && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt"

FROM node:${NODEJS_VERSION}-slim AS build_jellyfin_web

WORKDIR /jellyfin

COPY --from=get_info /tmp/BUILDTMP/JELLYFIN_WEB /jellyfin

RUN \
    apt update \
    && apt install git -qy \
    && npm ci --no-audit --unsafe-perm \
    && npm run build:production

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} as build_jellyfin

WORKDIR /jellyfin

COPY --from=get_info /tmp/BUILDTMP/JELLYFIN /jellyfin

ENV \
    DOTNET_CLI_TELEMETRY_OPTOUT="1"

RUN \
    dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/jellyfin/output" --self-contained --runtime linux-$(cat "/jellyfin/SYS_ARCH") -p:DebugSymbols=false -p:DebugType=none

FROM debian:stable-slim AS rebased_jellyfin

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_jellyfin /jellyfin/output /app/jellyfin

COPY --from=build_jellyfin /jellyfin/jellyfin-archive-keyring.gpg /usr/share/keyrings/jellyfin-archive-keyring.gpg

COPY --from=build_jellyfin_web /jellyfin/dist /app/jellyfin-web

RUN \
    export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && echo "deb [signed-by=/usr/share/keyrings/jellyfin-archive-keyring.gpg] https://repo.jellyfin.org/debian ${LSBCodename} main unstable" > "/etc/apt/sources.list.d/jellyfin.list" \
    && apt update -o Acquire::https::Verify-Peer=false \
    && apt install -qy -o Acquire::https::Verify-Peer=false \
          jellyfin-ffmpeg7 \
          libicu-dev \
          libssl-dev \
    && if [ "$(uname -m)" = "x86_64" ]; then \
        apt install -qy -o Acquire::https::Verify-Peer=false \
          mesa-va-drivers; \
    fi \
    && apt full-upgrade -qy -o Acquire::https::Verify-Peer=false \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i "s/http:/https:/g;s/deb.debian.org/mirrors.ustc.edu.cn/g;s|main|main contrib non-free non-free-firmware|g;s/stable/${LSBCodename:-stable}/g" "/etc/apt/sources.list.d/debian.sources" \
    && sed -i 's/deb/# deb/g' "/etc/apt/sources.list.d/jellyfin.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    PGID="0" PUID="0" \
    NVIDIA_DRIVER_CAPABILITIES="all" NVIDIA_VISIBLE_DEVICES="all" \
    ROC_ENABLE_PRE_VEGA="1"

COPY --from=rebased_jellyfin / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/app/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", "--webdir", "/app/jellyfin-web"]
