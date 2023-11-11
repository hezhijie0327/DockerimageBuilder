# Current Version: 1.6.6

FROM hezhijie0327/gpg:latest AS GET_GITHUB

FROM ubuntu:latest AS GET_CODEMANE

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat '/etc/os-release' | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g' > "${WORKDIR}/codename"

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/arch"

FROM hezhijie0327/base:ubuntu AS BUILD_FFMPEG

WORKDIR /tmp

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

RUN export WORKDIR=$(pwd) && export SYS_ARCH=$(cat "${WORKDIR}/BUILDTMP/arch" | sed "s/x64/amd64/g") && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDKIT/ffmpeg" && cd "${WORKDIR}/BUILDKIT/ffmpeg" && curl -Ls -o - "https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-${SYS_ARCH}-static.tar.xz" | tar Jxvf - --strip-components=1

FROM --platform=linux/amd64 hezhijie0327/module:binary-dotnet AS BUILD_DOTNET

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu as BUILD_JELLYFIN

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

COPY --from=BUILD_DOTNET / /tmp/BUILDLIB/DOTNET/

WORKDIR /tmp

ENV DOTNET_CLI_TELEMETRY_OPTOUT="1"

RUN export WORKDIR=$(pwd) && export DOTNET_ROOT=${WORKDIR}/BUILDLIB/DOTNET && export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN" && git clone -b $(cat "${WORKDIR}/jellyfin.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export JELLYFIN_SHA=$(cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git rev-parse --short HEAD | cut -c 1-4) && export JELLYFIN_VERSION=$(cat "${WORKDIR}/jellyfin.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4) && export JELLYFIN_CUSTOM_VERSION="${JELLYFIN_VERSION}-ZHIJIE+${JELLYFIN_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git submodule update --init && sed -i "s/Jellyfin version: {Version}/Jellyfin version: ${JELLYFIN_CUSTOM_VERSION}/g" "${WORKDIR}/BUILDTMP/JELLYFIN/Jellyfin.Server/Program.cs" && if [ $(cat "${WORKDIR}/BUILDTMP/arch") = "arm64" ]; then find . -type d -name obj | xargs -r rm -r && dotnet publish Jellyfin.Server --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-arm64 -p:DebugSymbols=false -p:DebugType=none; else dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-x64 -p:DebugSymbols=false -p:DebugType=none; fi

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild" | sed "s/\.git/-web\.git/g") "${WORKDIR}/BUILDTMP/jellyfin-web" && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm config set registry "https://registry.npmmirror.com" && npm ci --no-audit --unsafe-perm && npm run build:production && mv "${WORKDIR}/BUILDTMP/jellyfin-web/dist" "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /tmp/BUILDKIT/jellyfin

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/jellyfin/jellyfin"

FROM ubuntu:latest AS REBASED_JELLYFIN

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=GPG_SIGN /tmp/BUILDKIT/jellyfin /opt/jellyfin

COPY --from=BUILD_FFMPEG /tmp/BUILDKIT/ffmpeg /opt/ffmpeg

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
    && apt full-upgrade -qy \
    && apt install -qy --no-install-recommends --no-install-suggests libfontconfig1 libfreetype6 libharfbuzz0b libicu-dev \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="all" NVIDIA_VISIBLE_DEVICES="all" PGID="0" PUID="0" ROC_ENABLE_PRE_VEGA="1"

COPY --from=REBASED_JELLYFIN / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/opt/jellyfin/jellyfin", "--ffmpeg", "/opt/ffmpeg/ffmpeg", "--webdir", "/opt/jellyfin-web"]
