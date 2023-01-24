# Current Version: 1.1.9

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") && cd jellyfin && git submodule update --init && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "${WORKDIR}/arch" && curl -s --connect-timeout 15 "https://repo.radeon.com/rocm/rocm.gpg.key" | gpg --dearmor > "${WORKDIR}/amd.gpg" && curl -s --connect-timeout 15 "https://repositories.intel.com/graphics/intel-graphics.key" | gpg --dearmor > "${WORKDIR}/intel.gpg" && curl -s --connect-timeout 15 "https://repo.jellyfin.org/jellyfin_team.gpg.key" | gpg --dearmor > "${WORKDIR}/jellyfin.gpg" && curl -s --connect-timeout 15 "https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub" | gpg --dearmor > "${WORKDIR}/nvidia.gpg" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch-fbc.sh" > "${WORKDIR}/patch-fbc.sh" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh" > "${WORKDIR}/patch.sh"

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:6.0 as BUILD_JELLYFIN

COPY --from=GET_INFO /tmp/arch /tmp/BUILDTMP/arch
COPY --from=GET_INFO /tmp/jellyfin /tmp/BUILDTMP/jellyfin
COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

WORKDIR /tmp/BUILDTMP/jellyfin

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN if [ $(cat "/tmp/BUILDTMP/arch") = "arm64" ]; then find . -type d -name obj | xargs -r rm -r && dotnet publish Jellyfin.Server --configuration Release --output="/tmp/BUILDKIT/jellyfin" --self-contained --runtime linux-arm64 -p:DebugSymbols=false -p:DebugType=none; else dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/tmp/BUILDKIT/jellyfin" --self-contained --runtime linux-x64 -p:DebugSymbols=false -p:DebugType=none; fi

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/
COPY --from=GET_INFO /tmp/jellyfin.*.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild" | sed "s/\.git/-web\.git/g") "${WORKDIR}/BUILDTMP/jellyfin-web" && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm ci --no-audit --unsafe-perm && mv "${WORKDIR}/BUILDTMP/jellyfin-web/dist" "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM ubuntu:latest AS REBASED_JELLYFIN

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=GET_INFO /tmp/amd.gpg /usr/share/keyrings/amd.gpg
COPY --from=GET_INFO /tmp/intel.gpg /usr/share/keyrings/intel.gpg
COPY --from=GET_INFO /tmp/jellyfin.gpg /usr/share/keyrings/jellyfin.gpg
COPY --from=GET_INFO /tmp/nvidia.gpg /usr/share/keyrings/nvidia.gpg
COPY --from=GET_INFO /tmp/patch-fbc.sh /opt/nvidia-patch/patch-fbc.sh
COPY --from=GET_INFO /tmp/patch.sh /opt/nvidia-patch/patch.sh
COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /jellyfin
COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT/jellyfin-web /jellyfin/jellyfin-web

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -qy openssl \
    && echo "# deb [signed-by=/usr/share/keyrings/amd.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main proprietary" > "/etc/apt/sources.list.d/amd.list" \
    && echo "# deb [arch=amd64 signed-by=/usr/share/keyrings/amd.gpg] https://repo.radeon.com/rocm/apt/latest $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main proprietary" >> "/etc/apt/sources.list.d/amd.list" \
    && echo "# deb-src [signed-by=/usr/share/keyrings/amd.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main proprietary" >> "/etc/apt/sources.list.d/amd.list" \
    && echo "# deb [arch=amd64 signed-by=/usr/share/keyrings/intel.gpg] https://repositories.intel.com/graphics/ubuntu $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) arc legacy" > "/etc/apt/sources.list.d/intel.list" \
    && echo "# deb [arch=$( dpkg --print-architecture ) signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" > "/etc/apt/sources.list.d/jellyfin.list" \
    && echo "# deb [signed-by=/usr/share/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/$(. /etc/os-release;echo $ID$VERSION_ID | tr -d .)/x86_64/ /" > "/etc/apt/sources.list.d/nvidia.list" \
    && cat "/etc/apt/sources.list.d/jellyfin.list" | sed "s/# //g" > "/etc/apt/sources.list.d/jellyfin_build.list" \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -qy jellyfin-ffmpeg5 \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /etc/apt/sources.list.d/jellyfin_build.list \
    && sed -i "s/http:/https:/g;s/archive.ubuntu.com/mirrors.ustc.edu.cn/g;s/ports.ubuntu.com/mirrors.ustc.edu.cn/g;s/security.ubuntu.com/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list"

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" NVIDIA_VISIBLE_DEVICES="all"

COPY --from=REBASED_JELLYFIN / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg"]
