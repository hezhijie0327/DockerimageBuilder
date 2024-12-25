# Current Version: 1.9.7

FROM hezhijie0327/base:alpine AS get_info

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
    && git clone -b $(cat "${WORKDIR}/jellyfin_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin_web.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN_WEB" \
    && git clone -b $(cat "${WORKDIR}/jellyfin_web.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin_web.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export JELLYFIN_SHA=$(cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export JELLYFIN_VERSION=$(cat "${WORKDIR}/jellyfin.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export JELLYFIN_CUSTOM_VERSION="${JELLYFIN_VERSION}-ZHIJIE-${JELLYFIN_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/JELLYFIN" \
    && git submodule update --init \
    && cd "${WORKDIR}/BUILDTMP/JELLYFIN_WEB" \
    && sed -i "s/systemInfo.Version/'${JELLYFIN_CUSTOM_VERSION}'/g" "${WORKDIR}/BUILDTMP/JELLYFIN_WEB/src/controllers/dashboard/dashboard.js" \
    && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/BUILDTMP/JELLYFIN/SYS_ARCH" \
    && curl -s --connect-timeout 15 "https://repo.jellyfin.org/jellyfin_team.gpg.key" | gpg --dearmor > "${WORKDIR}/BUILDTMP/JELLYFIN/jellyfin-archive-keyring.gpg"

FROM --platform=linux/amd64 node:lts-slim AS build_jellyfin_web

WORKDIR /jellyfin

COPY --from=get_info /tmp/BUILDTMP/JELLYFIN_WEB /jellyfin

RUN \
    apt update \
    && apt install git -qy \
    && npm ci --no-audit --unsafe-perm \
    && npm run build:production

FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:9.0 as build_jellyfin

WORKDIR /jellyfin

COPY --from=get_info /tmp/BUILDTMP/JELLYFIN /jellyfin

ENV \
    DOTNET_CLI_TELEMETRY_OPTOUT="1"

RUN \
    dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/jellyfin/output" --self-contained --runtime linux-$(cat "/jellyfin/SYS_ARCH") -p:DebugSymbols=false -p:DebugType=none

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=build_jellyfin /jellyfin/output /tmp/BUILDKIT/jellyfin

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/jellyfin/jellyfin"

FROM debian:stable-slim AS rebased_jellyfin

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=gpg_sign /tmp/BUILDKIT/jellyfin /opt/jellyfin

COPY --from=build_jellyfin /jellyfin/jellyfin-archive-keyring.gpg /usr/share/keyrings/jellyfin-archive-keyring.gpg

COPY --from=build_jellyfin_web /jellyfin/dist /opt/jellyfin-web

RUN \
    rm -rf /etc/apt/sources.list.d/*.* \
    && export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && echo "deb http://mirrors.ustc.edu.cn/debian-security ${LSBCodename}-security contrib main non-free non-free-firmware" > "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename} contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports-sloppy contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-proposed-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian-security ${LSBCodename}-security contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename} contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports-sloppy contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-proposed-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb [signed-by=/usr/share/keyrings/jellyfin-archive-keyring.gpg] https://repo.jellyfin.org/debian ${LSBCodename} main unstable" > "/etc/apt/sources.list.d/jellyfin.list" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-backports" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 990" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-security" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-updates" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-proposed" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 100" >> "/etc/apt/preferences" \
    && apt update \
    && apt install -qy jellyfin-ffmpeg6 \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
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

ENTRYPOINT ["/opt/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", "--webdir", "/opt/jellyfin-web"]
