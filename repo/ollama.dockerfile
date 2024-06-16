# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.ollama" > "${WORKDIR}/ollama.json" && cat "${WORKDIR}/ollama.json" | jq -Sr ".version" && cat "${WORKDIR}/ollama.json" | jq -Sr ".source" > "${WORKDIR}/ollama.source.autobuild" && cat "${WORKDIR}/ollama.json" | jq -Sr ".source_branch" > "${WORKDIR}/ollama.source_branch.autobuild" && cat "${WORKDIR}/ollama.json" | jq -Sr ".patch" > "${WORKDIR}/ollama.patch.autobuild" && cat "${WORKDIR}/ollama.json" | jq -Sr ".patch_branch" > "${WORKDIR}/ollama.patch_branch.autobuild" && cat "${WORKDIR}/ollama.json" | jq -Sr ".version" > "${WORKDIR}/ollama.version.autobuild" && curl -s --connect-timeout 15 "https://repo.radeon.com/rocm/rocm.gpg.key" | gpg --dearmor > "${WORKDIR}/amd-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://repositories.intel.com/graphics/intel-graphics.key" | gpg --dearmor > "${WORKDIR}/intel-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB" | gpg --dearmor > "${WORKDIR}/intel-oneapi-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub" | gpg --dearmor > "${WORKDIR}/nvidia-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://nvidia.github.io/libnvidia-container/gpgkey" | gpg --dearmor > "${WORKDIR}/libnvidia-archive-keyring.gpg" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch-fbc.sh" > "${WORKDIR}/patch-fbc.sh" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh" > "${WORKDIR}/patch.sh"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_OLLAMA

WORKDIR /tmp

COPY --from=GET_INFO /tmp/ollama.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/ollama.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/ollama.source.autobuild") "${WORKDIR}/BUILDTMP/OLLAMA" && git clone -b $(cat "${WORKDIR}/ollama.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/ollama.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export OLLAMA_SHA=$(cd "${WORKDIR}/BUILDTMP/OLLAMA" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export OLLAMA_VERSION=$(cat "${WORKDIR}/ollama.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export OLLAMA_CUSTOM_VERSION="${OLLAMA_VERSION}-ZHIJIE-${OLLAMA_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/OLLAMA" && go generate ./... && go mod tidy && go get -u && go mod download && go mod vendor && export CGO_ENABLED=1 && go build -o ollama -trimpath -ldflags "-w -s -X=github.com/ollama/ollama/version.Version=$OLLAMA_CUSTOM_VERSION -X=github.com/ollama/ollama/server.mode=release" && cp -rf "${WORKDIR}/BUILDTMP/OLLAMA/ollama" "${WORKDIR}/BUILDKIT/ollama"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_OLLAMA /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/ollama"

FROM ubuntu:latest AS REBASED_OLLAMA

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=GET_INFO /tmp/*-archive-keyring.gpg /usr/share/keyrings/
COPY --from=GET_INFO /tmp/patch*.sh /opt/nvidia-patch/

COPY --from=GPG_SIGN /tmp/BUILDKIT/ollama /opt/ollama/ollama

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && rm -rf /etc/apt/sources.list.d/*.* \
    && export LSBVersion=$( . /etc/os-release;echo $VERSION_ID | tr -d . ) \
    && export OSArchitecture=$( dpkg --print-architecture ) \
    && if [ "${OSArchitecture}" = "amd64" ]; then export export NVIDIA_URL="x86_64" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu ${LSBCodename} main proprietary" > "/etc/apt/sources.list.d/amd.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/rocm/apt/latest ${LSBCodename} main proprietary" >> "/etc/apt/sources.list.d/amd.list" && echo "# deb-src [arch=${OSArchitecture} signed-by=/usr/share/keyrings/amd-archive-keyring.gpg] https://repo.radeon.com/amdgpu/latest/ubuntu ${LSBCodename} main proprietary" >> "/etc/apt/sources.list.d/amd.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/intel-archive-keyring.gpg] https://repositories.intel.com/graphics/ubuntu ${LSBCodename} arc legacy unified" > "/etc/apt/sources.list.d/intel.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/intel-oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" >> "/etc/apt/sources.list.d/intel.list" ; else export NVIDIA_URL="sbsa" && rm -rf "/usr/share/keyrings/amd-archive-keyring.gpg" "/usr/share/keyrings/intel-archive-keyring.gpg" "/usr/share/keyrings/intel-oneapi-archive-keyring.gpg" ; fi \
    && if [ "${OSArchitecture}" = "amd64" ] || [ "${OSArchitecture}" = "arm64" ]; then echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/libnvidia-archive-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/ubuntu18.04/${OSArchitecture} /" > "/etc/apt/sources.list.d/nvidia.list" && echo "# deb [arch=${OSArchitecture} signed-by=/usr/share/keyrings/nvidia-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${LSBVersion}/${NVIDIA_URL}/ /" >> "/etc/apt/sources.list.d/nvidia.list" ; fi \
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
    && apt update \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="all" NVIDIA_VISIBLE_DEVICES="all" ROC_ENABLE_PRE_VEGA="1" OLLAMA_HOST="0.0.0.0" OLLAMA_ORIGINS='*'

COPY --from=REBASED_OLLAMA / /

EXPOSE 11434/tcp

ENTRYPOINT ["/opt/ollama/ollama"]
