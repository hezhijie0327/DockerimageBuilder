# Current Version: 1.6.0

FROM hezhijie0327/gpg:latest AS GET_GITHUB

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/arch"

FROM --platform=linux/amd64 hezhijie0327/module:binary-dotnet AS BUILD_DOTNET

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu as BUILD_JELLYFIN

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

COPY --from=BUILD_DOTNET / /tmp/BUILDLIB/DOTNET/

WORKDIR /tmp

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN export WORKDIR=$(pwd) && export DOTNET_ROOT=${WORKDIR}/BUILDLIB/DOTNET && export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN" && git clone -b $(cat "${WORKDIR}/jellyfin.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export JELLYFIN_SHA=$(cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git rev-parse --short HEAD | cut -c 1-4) && export JELLYFIN_VERSION=$(cat "${WORKDIR}/jellyfin.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4) && export JELLYFIN_CUSTOM_VERSION="${JELLYFIN_VERSION}.${JELLYFIN_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git submodule update --init && if [ $(cat "${WORKDIR}/BUILDTMP/arch") = "arm64" ]; then find . -type d -name obj | xargs -r rm -r && dotnet publish Jellyfin.Server --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-arm64 -p:DebugSymbols=false -p:DebugType=none; else dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-x64 -p:DebugSymbols=false -p:DebugType=none; fi

FROM hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_FFMPEG

WORKDIR /tmp

COPY --from=GET_GITHUB /opt/github.api /tmp/BUILDTMP/github.api

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

RUN export WORKDIR=$(pwd) && GITHUB_API=$(cat "${WORKDIR}/BUILDTMP/github.api") && export SYS_CODENAME=$(cat '/etc/os-release' | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g') && export SYS_ARCH=$(cat "${WORKDIR}/BUILDTMP/arch" | sed "s/x64/amd64/g") && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDKIT/jellyfin-ffmpeg" "${WORKDIR}/BUILDTMP" && wget --header="Authorization: Bearer ${GITHUB_API}" -O "${WORKDIR}/BUILDTMP/jellyfin-ffmpeg.zip" $(curl -s --connect-timeout 15 -H "Authorization: Bearer ${GITHUB_API}" "https://api.github.com/repos/jellyfin/jellyfin-ffmpeg/actions/artifacts?name=ubuntu-${SYS_CODENAME}-${SYS_ARCH}&per_page=100" | jq -r '.artifacts[] | select(.workflow_run.head_branch == "jellyfin") | .archive_download_url' | head -n 1) && unzip -d "${WORKDIR}/BUILDKIT/jellyfin-ffmpeg" "${WORKDIR}/BUILDTMP/jellyfin-ffmpeg.zip"

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild" | sed "s/\.git/-web\.git/g") "${WORKDIR}/BUILDTMP/jellyfin-web" && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm ci --no-audit --unsafe-perm && npm run build:production && mv "${WORKDIR}/BUILDTMP/jellyfin-web/dist" "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /tmp/BUILDKIT/jellyfin

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/jellyfin/jellyfin"

FROM ubuntu:latest AS REBASED_JELLYFIN

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=GPG_SIGN /tmp/BUILDKIT/jellyfin /opt/jellyfin

COPY --from=BUILD_JELLYFIN_FFMPEG /tmp/BUILDKIT/jellyfin-ffmpeg /tmp/BUILDTMP/jellyfin-ffmpeg

COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT/jellyfin-web /opt/jellyfin-web

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && if [ $( dpkg --print-architecture ) = "amd64" ]; then export MIRROR_URL="ubuntu" ; else export MIRROR_URL="ubuntu-ports" ; fi \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" > "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
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
    && apt install -qy openssl /tmp/BUILDTMP/jellyfin-ffmpeg/*.deb \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="all" NVIDIA_VISIBLE_DEVICES="all" PGID="0" PUID="0" ROC_ENABLE_PRE_VEGA="1"

COPY --from=REBASED_JELLYFIN / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/opt/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", "--webdir", "/opt/jellyfin-web"]
