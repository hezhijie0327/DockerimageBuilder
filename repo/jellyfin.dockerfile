# Current Version: 2.1.7

ARG DOTNET_VERSION="9.0"
ARG NODEJS_VERSION="22"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" \
    && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" \
    && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" \
    && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" \
    && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" \
    && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" \
    && cat "/opt/package.json" | jq -Sr ".repo.jellyfin_web" > "${WORKDIR}/jellyfin_web.json" \
    && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin_web.source.autobuild" \
    && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin_web.source_branch.autobuild" \
    && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin_web.patch.autobuild" \
    && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin_web.patch_branch.autobuild" \
    && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin_web.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN" \
    && git clone -b $(cat "${WORKDIR}/jellyfin.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/jellyfin_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin_web.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN_WEB" \
    && export JELLYFIN_SHA=$(cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export JELLYFIN_VERSION=$(cat "${WORKDIR}/jellyfin.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export JELLYFIN_CUSTOM_VERSION="${JELLYFIN_VERSION}-ZHIJIE-${JELLYFIN_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/JELLYFIN" \
    && git submodule update --init \
    && cd "${WORKDIR}/BUILDTMP/JELLYFIN_WEB" \
    && sed -i "s/systemInfo.Version/'${JELLYFIN_CUSTOM_VERSION}'/g" "${WORKDIR}/BUILDTMP/JELLYFIN_WEB/src/apps/dashboard/controllers/dashboard.js" \
    && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/BUILDTMP/JELLYFIN/SYS_ARCH" \
    && curl -s --connect-timeout 15 "https://repo.jellyfin.org/jellyfin_team.gpg.key" | gpg --dearmor > "${WORKDIR}/BUILDTMP/JELLYFIN/jellyfin-archive-keyring.gpg"

FROM node:${NODEJS_VERSION}-slim AS build_jellyfin_web

WORKDIR /jellyfin

COPY --from=get_info /tmp/BUILDTMP/JELLYFIN_WEB /jellyfin

RUN \
    apt update \
    && apt install fonts-noto-cjk git -qy \
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

COPY --from=build_jellyfin_web /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc

RUN \
    echo "deb [signed-by=/usr/share/keyrings/jellyfin-archive-keyring.gpg] https://repo.jellyfin.org/debian $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main unstable" > "/etc/apt/sources.list.d/jellyfin.list" \
    && apt update \
    && apt install -qy \
          jellyfin-ffmpeg7 \
          libssl-dev \
    && if [ "$(uname -m)" = "x86_64" ]; then \
        apt install -qy \
          mesa-va-drivers; \
    fi \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g;s/deb.debian.org/mirrors.ustc.edu.cn/g;s|main|main contrib non-free non-free-firmware|g' "/etc/apt/sources.list.d/debian.sources" \
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
