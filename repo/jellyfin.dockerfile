# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN git clone --depth=1 https://github.com/jellyfin/jellyfin

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM mcr.microsoft.com/dotnet/sdk:7.0 as BUILD_JELLYFIN

COPY --from=GET_INFO /tmp/jellyfin /tmp/BUILDTMP/jellyfin

WORKDIR /tmp/BUILDTMP/jellyfin

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/tmp/BUILDKIT/jellyfin" --self-contained --runtime linux-$(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") -p:DebugSymbols=false -p:DebugType=none

FROM hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone --depth=1 "https://github.com/jellyfin/jellyfin-web" "${WORKDIR}/BUILDTMP/jellyfin-web" && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm ci --no-audit --unsafe-perm && mv "${WORKDIR}/BUILDTMP/jellyfin-web/dist" "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM ubuntu:latest

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /jellyfin
COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT/jellyfin-web /jellyfin/jellyfin-web

RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y ca-certificates gnupg wget curl \
    && wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | apt-key add - \
    && echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | tee /etc/apt/sources.list.d/jellyfin.list \
    && apt-get update \
    && if [ $(uname -m | sed "s/x86_64/amd64/g;s/x86-64/amd64/g;s/x64/amd64/g;s/aarch64/arm64/g") == "amd64" ]; then apt install --no-install-recommends --no-install-suggests -y mesa-va-drivers; fi \
    && if [ $(uname -m | sed "s/x86_64/amd64/g;s/x86-64/amd64/g;s/x64/amd64/g;s/aarch64/arm64/g") == "arm64" ]; then apt install --no-install-recommends --no-install-suggests -y libomxil-bellagio0 libomxil-bellagio-bin libraspberrypi0; fi \
    && apt-get install --no-install-recommends --no-install-suggests -y \
    jellyfin-ffmpeg5 \
    libfontconfig1 \
    libfreetype6 \
    libssl3 \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

EXPOSE 8096/tcp 8920/tcp

ENTRYPOINT ["/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg"]
