# Current Version: 1.4.6

FROM hezhijie0327/gpg:latest AS GET_GITHUB

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/arch" && curl -s --connect-timeout 15 "https://repo.radeon.com/rocm/rocm.gpg.key" | gpg --dearmor > "${WORKDIR}/amd.gpg" && curl -s --connect-timeout 15 "https://repositories.intel.com/graphics/intel-graphics.key" | gpg --dearmor > "${WORKDIR}/intel.gpg" && curl -s --connect-timeout 15 "https://repo.jellyfin.org/jellyfin_team.gpg.key" | gpg --dearmor > "${WORKDIR}/jellyfin.gpg" && curl -s --connect-timeout 15 "https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub" | gpg --dearmor > "${WORKDIR}/nvidia.gpg" && curl -s --connect-timeout 15 "https://nvidia.github.io/libnvidia-container/gpgkey" | gpg --dearmor > "${WORKDIR}/libnvidia.gpg" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch-fbc.sh" > "${WORKDIR}/patch-fbc.sh" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh" > "${WORKDIR}/patch.sh"

FROM --platform=linux/amd64 hezhijie0327/module:binary-dotnet AS BUILD_DOTNET

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu as BUILD_JELLYFIN

COPY --from=BUILD_DOTNET / /tmp/BUILDLIB/DOTNET/
COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch
COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

WORKDIR /tmp

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_SYSTEM_GLOBALIZATION_USENLS=true

RUN export WORKDIR=$(pwd) && export DOTNET_ROOT=${WORKDIR}/BUILDLIB/DOTNET && export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") "${WORKDIR}/BUILDTMP/JELLYFIN" && cd "${WORKDIR}/BUILDTMP/JELLYFIN" && git submodule update --init && if [ $(cat "${WORKDIR}/BUILDTMP/arch") = "arm64" ]; then find . -type d -name obj | xargs -r rm -r && dotnet publish Jellyfin.Server --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-arm64 -p:DebugSymbols=false -p:DebugType=none; else dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="${WORKDIR}/BUILDKIT/jellyfin" --self-contained --runtime linux-x64 -p:DebugSymbols=false -p:DebugType=none; fi

FROM hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_FFMPEG

WORKDIR /tmp

COPY --from=GET_GITHUB /opt/github.api /tmp/BUILDTMP/github.api
COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch

RUN export WORKDIR=$(pwd) && GITHUB_API=$(cat "${WORKDIR}/BUILDTMP/github.api") && export SYS_CODENAME=$(cat '/etc/os-release' | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g') && export SYS_ARCH=$(cat "${WORKDIR}/BUILDTMP/arch" | sed "s/x64/amd64/g") && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDKIT/jellyfin-ffmpeg" "${WORKDIR}/BUILDTMP" && wget --header="Authorization: Bearer ${GITHUB_API}" -O "${WORKDIR}/BUILDTMP/jellyfin-ffmpeg.zip" $(curl -s --connect-timeout 15 -H "Authorization: Bearer ${GITHUB_API}" "https://api.github.com/repos/jellyfin/jellyfin-ffmpeg/actions/artifacts?name=ubuntu-${SYS_CODENAME}-${SYS_ARCH}&per_page=100" | jq -r '.artifacts[] | select(.workflow_run.head_branch == "jellyfin") | .archive_download_url' | head -n 1) && unzip -d "${WORKDIR}/BUILDKIT/jellyfin-ffmpeg" "${WORKDIR}/BUILDTMP/jellyfin-ffmpeg.zip"

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/
COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild" | sed "s/\.git/-web\.git/g") "${WORKDIR}/BUILDTMP/jellyfin-web" && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm ci --no-audit --unsafe-perm && npm run build:production && mv "${WORKDIR}/BUILDTMP/jellyfin-web/dist" "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /tmp/BUILDKIT/jellyfin

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/jellyfin/jellyfin"

FROM ubuntu:latest AS REBASED_JELLYFIN

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=GET_INFO /tmp/amd.gpg /usr/share/keyrings/amd-archive-keyring.gpg
COPY --from=GET_INFO /tmp/intel.gpg /usr/share/keyrings/intel-archive-keyring.gpg
COPY --from=GET_INFO /tmp/jellyfin.gpg /usr/share/keyrings/jellyfin-archive-keyring.gpg
COPY --from=GET_INFO /tmp/libnvidia.gpg /usr/share/keyrings/libnvidia-archive-keyring.gpg
COPY --from=GET_INFO /tmp/nvidia.gpg /usr/share/keyrings/nvidia-archive-keyring.gpg
COPY --from=GET_INFO /tmp/patch-fbc.sh /opt/nvidia-patch/patch-fbc.sh
COPY --from=GET_INFO /tmp/patch.sh /opt/nvidia-patch/patch.sh
COPY --from=GPG_SIGN /tmp/BUILDKIT/jellyfin /opt/jellyfin
COPY --from=BUILD_JELLYFIN_FFMPEG /tmp/BUILDKIT/jellyfin-ffmpeg /tmp/BUILDTMP/jellyfin-ffmpeg
COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT/jellyfin-web /opt/jellyfin-web

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && export LSBVersion=$( . /etc/os-release;echo $VERSION_ID | tr -d . ) \
    && export OSArchitecture=$( dpkg --print-architecture ) \
    && if [ "${OSArchitecture}" = "amd64" ]; then export MIRROR_URL="ubuntu" && export NVIDIA_URL="x86_64" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu ${LSBCodename} main proprietary" > "/etc/apt/sources.list.d/amd.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/rocm/apt/latest ${LSBCodename} main proprietary" >> "/etc/apt/sources.list.d/amd.list" && echo "# deb-src [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu ${LSBCodename} main proprietary" >> "/etc/apt/sources.list.d/amd.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/intel-archive-keyring.gpg] https://repositories.intel.com/graphics/ubuntu ${LSBCodename} arc legacy" > "/etc/apt/sources.list.d/intel.list" ; else export MIRROR_URL="ubuntu-ports" && export NVIDIA_URL="sbsa" && rm -rf "/usr/share/keyrings/amd-archive-keyring.gpg" "/usr/share/keyrings/intel-archive-keyring.gpg" ; fi \
    && if [ "${OSArchitecture}" = "amd64" ] || [ "${OSArchitecture}" = "arm64" ]; then echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/jellyfin-archive-keyring.gpg] https://repo.jellyfin.org/ubuntu ${LSBCodename} main" > "/etc/apt/sources.list.d/jellyfin.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/libnvidia-archive-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/ubuntu18.04/${OSArchitecture} /" > "/etc/apt/sources.list.d/nvidia.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/nvidia-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${LSBVersion}/${NVIDIA_URL}/ /" >> "/etc/apt/sources.list.d/nvidia.list" ; fi \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" > "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
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
    && apt install -qy /tmp/BUILDTMP/jellyfin-ffmpeg/*.deb \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="all" NVIDIA_VISIBLE_DEVICES="all"

COPY --from=REBASED_JELLYFIN / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/opt/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", "--webdir", "/opt/jellyfin-web"]
