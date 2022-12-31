# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN git clone https://github.com/jellyfin/jellyfin --depth=1

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} as BUILD_JELLYFIN

COPY --from=GET_INFO /tmp/jellyfin /tmp/BUILDTMP/jellyfin

WORKDIR /tmp/BUILDTMP/jellyfin

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/jellyfin" --self-contained --runtime linux-x64 -p:DebugSymbols=false -p:DebugType=none

FROM hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone https://github.com/jellyfin/jellyfin-web --depth=1 && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm ci --no-audit --unsafe-perm && mv "${WORKDIR}/BUILDTMP/jellyfin-web/dist" "/jellyfin-web"

FROM debian:stable-slim

ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE="DontWarn"
ARG DEBIAN_FRONTEND="noninteractive"
ARG GMMLIB_VERSION="22.0.2"
ARG IGC_VERSION="1.0.10395"
ARG LEVEL_ZERO_VERSION="1.3.22549"
ARG NEO_VERSION="22.08.22549"

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility,video"

COPY --from=BUILD_JELLYFIN /jellyfin /jellyfin
COPY --from=BUILD_JELLYFIN_WEB /jellyfin-web /jellyfin/jellyfin-web

RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y ca-certificates gnupg wget curl \
    && wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | apt-key add - \
    && echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | tee /etc/apt/sources.list.d/jellyfin.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    jellyfin-ffmpeg \
    locales \
    mesa-va-drivers \
    openssl \
    && mkdir intel-compute-runtime \
    && cd intel-compute-runtime \
    && wget https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/intel-gmmlib_${GMMLIB_VERSION}_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/intel-level-zero-gpu_${LEVEL_ZERO_VERSION}_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/intel-opencl-icd_${NEO_VERSION}_amd64.deb \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-${IGC_VERSION}/intel-igc-core_${IGC_VERSION}_amd64.deb \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-${IGC_VERSION}/intel-igc-opencl_${IGC_VERSION}_amd64.deb \
    && dpkg -i *.deb \
    && cd .. \
    && rm -rf intel-compute-runtime \
    && apt-get remove gnupg wget -y \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

EXPOSE 8096/tcp 8920/tcp

ENTRYPOINT ["/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg"]
