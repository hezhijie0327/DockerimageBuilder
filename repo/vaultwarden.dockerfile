# Current Version: 1.1.7

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.vaultwarden" > "${WORKDIR}/vaultwarden.json" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".source" > "${WORKDIR}/vaultwarden.source.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".source_branch" > "${WORKDIR}/vaultwarden.source_branch.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".patch" > "${WORKDIR}/vaultwarden.patch.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".patch_branch" > "${WORKDIR}/vaultwarden.patch_branch.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".version" > "${WORKDIR}/vaultwarden.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.source.autobuild") "${WORKDIR}/BUILDTMP/VAULTWARDEN" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export VAULTWARDEN_SHA=$(cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_VERSION=$(cat "${WORKDIR}/vaultwarden.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_CUSTOM_VERSION="${VAULTWARDEN_VERSION}-ZHIJIE-${VAULTWARDEN_SHA}${PATCH_SHA}" \
    && echo "${VAULTWARDEN_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/VAULTWARDEN/VAULTWARDEN_CUSTOM_VERSION" \
    && mkdir -p "${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB" \
    && cd "${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB" \
    && export latest_version=$(curl -s "https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest" | jq -r .tag_name) \
    && curl -Ls -o - "https://github.com/dani-garcia/bw_web_builds/releases/download/${latest_version}/bw_web_${latest_version}.tar.gz" | tar zxvf - --strip-components=1 \
    && sed -i "s/Promise.resolve(\"[0-9]\+\(\.[0-9]\+\)*\")/Promise.resolve(\"${VAULTWARDEN_CUSTOM_VERSION}\")/g" ${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB/app/main.*.js

FROM rust:alpine as build_vaultwarden

WORKDIR /vaultwarden

COPY --from=get_info /tmp/BUILDTMP/VAULTWARDEN /vaultwarden

RUN \
    apk add --no-cache build-base openssl-dev openssl-libs-static \
    && export VW_VERSION=$(cat "/vaultwarden/VAULTWARDEN_CUSTOM_VERSION") \
    && cargo build --features sqlite --release

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt
COPY --from=get_info /tmp/BUILDTMP/VAULTWARDEN_WEB /tmp/BUILDKIT/web-vault

COPY --from=build_vaultwarden /vaultwarden/target/release/vaultwarden /tmp/BUILDKIT/vaultwarden

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vaultwarden"

FROM scratch

ENV \
    DATA_FOLDER="/etc/vaultwarden/data" \
    ROCKET_ADDRESS="0.0.0.0" ROCKET_PORT="8000" \
    WEB_VAULT_ENABLED="true" WEB_VAULT_FOLDER="/web-vault"

COPY --from=gpg_sign /tmp/BUILDKIT /

EXPOSE 8000/tcp

ENTRYPOINT ["/vaultwarden"]
