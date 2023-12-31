# Current Version: 1.0.1

FROM hezhijie0327/gpg:latest AS GET_GITHUB

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.vaultwarden" > "${WORKDIR}/vaultwarden.json" && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".version" && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".source" > "${WORKDIR}/vaultwarden.source.autobuild" && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".source_branch" > "${WORKDIR}/vaultwarden.source_branch.autobuild" && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".patch" > "${WORKDIR}/vaultwarden.patch.autobuild" && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".patch_branch" > "${WORKDIR}/vaultwarden.patch_branch.autobuild" && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".version" > "${WORKDIR}/vaultwarden.version.autobuild"

FROM hezhijie0327/module:binary-rust AS BUILD_RUST

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/module:glibc-sqlite AS BUILD_SQLITE

FROM hezhijie0327/base:ubuntu as BUILD_VAULTWARDEN

COPY --from=GET_INFO /tmp/vaultwarden.*.autobuild /tmp/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

COPY --from=BUILD_RUST / /tmp/BUILDLIB/

COPY --from=BUILD_SQLITE / /tmp/BUILDLIB/

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && export OPENSSL_DIR="${PREFIX}" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/vaultwarden.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.source.autobuild") "${WORKDIR}/BUILDTMP/VAULTWARDEN" && git clone -b $(cat "${WORKDIR}/vaultwarden.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export VAULTWARDEN_SHA=$(cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" && git rev-parse --short HEAD | cut -c 1-4) && export VAULTWARDEN_VERSION=$(cat "${WORKDIR}/vaultwarden.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4) && export VAULTWARDEN_CUSTOM_VERSION="${VAULTWARDEN_VERSION}-ZHIJIE+${VAULTWARDEN_SHA}${PATCH_SHA}" && bash "${WORKDIR}/BUILDLIB/install.sh" && cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" && cargo build --features sqlite --release && cp -rf "${WORKDIR}/BUILDTMP/VAULTWARDEN/target/release/vaultwarden" "${WORKDIR}/BUILDKIT/vaultwarden"

FROM hezhijie0327/base:alpine AS BUILD_VAULTWARDEN_WEB

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDTMP/VAULTWARDEN-WEB" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export latest_version=$(curl -s "https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest" | jq -r .tag_name) && cd "${WORKDIR}/BUILDTMP/VAULTWARDEN-WEB" && curl -Ls -o - "https://github.com/dani-garcia/bw_web_builds/releases/download/${latest_version}/bw_web_${latest_version}.tar.gz" | tar zxvf - --strip-components=1 && mv "${WORKDIR}/BUILDTMP/VAULTWARDEN-WEB" "${WORKDIR}/BUILDKIT/web-vault"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_VAULTWARDEN /tmp/BUILDKIT/vaultwarden /tmp/BUILDKIT/vaultwarden

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vaultwarden"

FROM ubuntu:rolling AS REBASED_VAULTWARDEN

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=GPG_SIGN /tmp/BUILDKIT/vaultwarden /opt/vaultwarden/vaultwarden

COPY --from=BUILD_VAULTWARDEN_WEB /tmp/BUILDKIT/web-vault /opt/vaultwarden/web-vault

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
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* \
    && ln -s /opt/vaultwarden/web-vault /web-vault

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=REBASED_VAULTWARDEN / /

EXPOSE 8000/tcp

ENTRYPOINT ["/opt/vaultwarden/vaultwarden"]
