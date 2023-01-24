# Current Version: 1.1.6

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.jellyfin" > "${WORKDIR}/jellyfin.json" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source" > "${WORKDIR}/jellyfin.source.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".source_branch" > "${WORKDIR}/jellyfin.source_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch" > "${WORKDIR}/jellyfin.patch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".patch_branch" > "${WORKDIR}/jellyfin.patch_branch.autobuild" && cat "${WORKDIR}/jellyfin.json" | jq -Sr ".version" > "${WORKDIR}/jellyfin.version.autobuild" && git clone -b $(cat "${WORKDIR}/jellyfin.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/jellyfin.source.autobuild") && cd jellyfin && git submodule update --init && echo $(uname -m | sed "s/x86_64/x64/g;s/x86-64/x64/g;s/amd64/x64/g;s/aarch64/arm64/g") > "/tmp/arch"

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

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /tmp/ca-certificates.crt
COPY --from=BUILD_JELLYFIN /tmp/BUILDKIT/jellyfin /jellyfin
COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT/jellyfin-web /jellyfin/jellyfin-web

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -qy ca-certificates gnupg openssl wget \
    && wget -O - "https://repo.jellyfin.org/jellyfin_team.gpg.key" | apt-key add - \
    && echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | tee /etc/apt/sources.list.d/jellyfin.list \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -qy jellyfin-ffmpeg5 \
    && apt purge -qy ca-certificates dbus-user-session dirmngr gnupg gnupg-l10n gnupg-utils gpg gpg-agent gpg-wks-client gpg-wks-server gpgconf gpgsm libassuan0 libksba8 libldap-2.5-0 libnpth0 libpam-systemd libpsl5 libreadline8 libsasl2-2 libsasl2-modules-db libsasl2-modules-gssapi-heimdal libsasl2-modules-gssapi-mit libsasl2-modules-ldap libsasl2-modules-otp libsasl2-modules-sql libsqlite3-0 parcimonie pinentry-curses pinentry-doc pinentry-gnome3 readline-common readline-doc scdaemon tor wget xloadimage \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && mkdir -p "/etc/ssl/certs" && mv /tmp/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /etc/apt/sources.list.d/jellyfin.list /etc/apt/trusted.gpg \
    && sed -i "s/http:/https:/g;s/archive.ubuntu.com/mirrors.ustc.edu.cn/g;s/ports.ubuntu.com/mirrors.ustc.edu.cn/g;s/security.ubuntu.com/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list"

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

COPY --from=REBASED_JELLYFIN / /

EXPOSE 1900/udp 7359/udp 8096/tcp 8920/tcp

ENTRYPOINT ["/jellyfin/jellyfin", "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg"]
