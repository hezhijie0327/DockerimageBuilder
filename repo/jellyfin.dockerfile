# Current Version: 1.8.8

FROM hezhijie0327/gpg:latest AS GET_GITHUB

FROM ubuntu:latest AS GET_CODEMANE

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat '/etc/os-release' | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g' > "${WORKDIR}/codename"

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" && cat "${WORKDIR}/package.json" | jq -Sr ".module.jellyfin_ffmpeg" > "${WORKDIR}/jellyfin_ffmpeg.json" && cat "${WORKDIR}/jellyfin_ffmpeg.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin_ffmpeg.json" | jq -Sr ".source" | sed "s/{JELLYFIN_FFMPEG_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/64/g" > "${WORKDIR}/jellyfin_ffmpeg.autobuild" && cat "${WORKDIR}/package.json" | jq -Sr ".repo.jellyfin_web" > "${WORKDIR}/jellyfin_web.json" && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin_web.source.autobuild" && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin_web.source_branch.autobuild" && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin_web.patch.autobuild" && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin_web.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin_web.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin_web.version.autobuild" && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/arch" && curl -s --connect-timeout 15 "https://repo.radeon.com/rocm/rocm.gpg.key" | gpg --dearmor > "${WORKDIR}/amd-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://repositories.intel.com/graphics/intel-graphics.key" | gpg --dearmor > "${WORKDIR}/intel-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub" | gpg --dearmor > "${WORKDIR}/nvidia-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://nvidia.github.io/libnvidia-container/gpgkey" | gpg --dearmor > "${WORKDIR}/libnvidia-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch-fbc.sh" > "${WORKDIR}/patch-fbc.sh" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh" > "${WORKDIR}/patch.sh" && curl -s --connect-timeout 15 "https://repo.jellyfin.org/jellyfin_team.gpg.key" | gpg --dearmor > "${WORKDIR}/jellyfin-archive-keyring.gpg"

FROM --platform=linux/amd64 hezhijie0327/module:binary-dotnet AS BUILD_DOTNET

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu as BUILD_JELLYFIN

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

COPY --from=BUILD_DOTNET / /tmp/BUILDLIB/DOTNET/

WORKDIR /tmp

ENV DOTNET_CLI_TELEMETRY_OPTOUT="1"

RUN export WORKDIR=$(pwd) && export DOTNET_ROOT=${WORKDIR}/BUILDLIB/DOTNET && export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools && export SYS_ARCH=$(cat "${WORKDIR}/BUILDTMP/arch") && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN" && cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git submodule update --init && dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-${SYS_ARCH} -p:DebugSymbols=false -p:DebugType=none

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=GET_INFO /tmp/jellyfin*.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN" && git clone -b $(cat "${WORKDIR}/jellyfin_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin_web.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN-WEB" && git clone -b $(cat "${WORKDIR}/jellyfin_web.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin_web.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export JELLYFIN_SHA=$(cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export JELLYFIN_VERSION=$(cat "${WORKDIR}/jellyfin.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export JELLYFIN_CUSTOM_VERSION="${JELLYFIN_VERSION}-ZHIJIE-${JELLYFIN_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/JELLYFIN-WEB" && sed -i "s/systemInfo.Version/'${JELLYFIN_CUSTOM_VERSION}'/g" "${WORKDIR}/BUILDTMP/JELLYFIN-WEB/src/controllers/dashboard/dashboard.js" && npm ci --no-audit --unsafe-perm && npm run build:production && mv "${WORKDIR}/BUILDTMP/JELLYFIN-WEB/dist" "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /tmp/BUILDKIT/jellyfin

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/jellyfin/jellyfin"

FROM ubuntu:latest AS REBASED_JELLYFIN

ENV DEBIAN_FRONTEND="noninteractive"

ADD ../patch/jellyfin/intel.sh /opt/intel-patch/patch.sh
ADD ../patch/jellyfin/intel.version /opt/intel-patch/intel.version

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=GET_INFO /tmp/*-archive-keyring.gpg /usr/share/keyrings/
COPY --from=GET_INFO /tmp/patch*.sh /opt/nvidia-patch/

COPY --from=GPG_SIGN /tmp/BUILDKIT/jellyfin /opt/jellyfin

COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT/jellyfin-web /opt/jellyfin-web

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && rm -rf /etc/apt/sources.list.d/*.* \
    && export LSBVersion=$( . /etc/os-release;echo $VERSION_ID | tr -d . ) \
    && export OSArchitecture=$( dpkg --print-architecture ) \
    && if [ "${OSArchitecture}" = "amd64" ]; then export export NVIDIA_URL="x86_64" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu ${LSBCodename} main proprietary" > "/etc/apt/sources.list.d/amd.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/rocm/apt/latest ${LSBCodename} main proprietary" >> "/etc/apt/sources.list.d/amd.list" && echo "# deb-src [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu ${LSBCodename} main proprietary" >> "/etc/apt/sources.list.d/amd.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/intel-archive-keyring.gpg] https://repositories.intel.com/gpu/ubuntu ${LSBCodename} unified" > "/etc/apt/sources.list.d/intel.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/intel-archive-keyring.gpg] https://repositories.intel.com/graphics/ubuntu ${LSBCodename} arc legacy unified" >> "/etc/apt/sources.list.d/intel.list" ; else export NVIDIA_URL="sbsa" && rm -rf "/usr/share/keyrings/amd-archive-keyring.gpg" "/usr/share/keyrings/intel-archive-keyring.gpg" "/opt/intel-patch" ; fi \
    && if [ "${OSArchitecture}" = "amd64" ] || [ "${OSArchitecture}" = "arm64" ]; then echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/libnvidia-archive-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/ubuntu18.04/${OSArchitecture} /" > "/etc/apt/sources.list.d/nvidia.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/nvidia-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${LSBVersion}/${NVIDIA_URL}/ /" >> "/etc/apt/sources.list.d/nvidia.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/jellyfin-archive-keyring.gpg] https://repo.jellyfin.org/ubuntu ${LSBCodename} main unstable" > "/etc/apt/sources.list.d/jellyfin.list" ; fi \
    && if [ "${OSArchitecture}" = "amd64" ]; then export MIRROR_URL="ubuntu" ; else export MIRROR_URL="ubuntu-ports" ; fi \
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
    && sed -i 's/# //g' "/etc/apt/sources.list.d/jellyfin.list" \
    && apt update \
    && apt install -qy jellyfin-ffmpeg6 \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" GHPROXY_URL="" NVIDIA_DRIVER_CAPABILITIES="all" NVIDIA_VISIBLE_DEVICES="all" PGID="0" PUID="0" ROC_ENABLE_PRE_VEGA="1"

COPY --from=REBASED_JELLYFIN / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/opt/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", "--webdir", "/opt/jellyfin-web"]
