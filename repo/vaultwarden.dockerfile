# Current Version: 1.2.5

ARG NODEJS_VERSION="22"
ARG RUST_VERSION="1"

FROM hezhijie0327/module:alpine AS get_info

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
    && cat "/opt/package.json" | jq -Sr ".repo.vaultwarden_web" > "${WORKDIR}/vaultwarden_web.json" \
    && cat "${WORKDIR}/vaultwarden_web.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/vaultwarden_web.json" | jq -Sr ".source" > "${WORKDIR}/vaultwarden_web.source.autobuild" \
    && cat "${WORKDIR}/vaultwarden_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/vaultwarden_web.source_branch.autobuild" \
    && cat "${WORKDIR}/vaultwarden_web.json" | jq -Sr ".patch" > "${WORKDIR}/vaultwarden_web.patch.autobuild" \
    && cat "${WORKDIR}/vaultwarden_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/vaultwarden_web.patch_branch.autobuild" \
    && cat "${WORKDIR}/vaultwarden_web.json" | jq -Sr ".version" > "${WORKDIR}/vaultwarden_web.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.source.autobuild") "${WORKDIR}/BUILDTMP/VAULTWARDEN" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden_web.source.autobuild") "${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB" \
    && export VAULTWARDEN_SHA=$(cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_VERSION=$(cat "${WORKDIR}/vaultwarden.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_CUSTOM_VERSION="${VAULTWARDEN_VERSION}-ZHIJIE-${VAULTWARDEN_SHA}${PATCH_SHA}" \
    && echo "${VAULTWARDEN_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/VAULTWARDEN/VAULTWARDEN_CUSTOM_VERSION" \
    && echo "${VAULTWARDEN_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB/VAULTWARDEN_CUSTOM_VERSION"

FROM node:${NODEJS_VERSION}-slim AS build_vaultwarden_web

WORKDIR /vaultwarden

ENV \
    VAULT_FOLDER="bw_clients"

COPY --from=get_info /tmp/BUILDTMP/VAULTWARDEN_WEB /vaultwarden

RUN \
    apt update \
    && apt install -qy \
          git \
    && export VAULT_VERSION=$(cat ./Dockerfile | grep "ARG VAULT_VERSION" | cut -d '=' -f 2) \
    && ./scripts/checkout_web_vault.sh \
    && ./scripts/patch_web_vault.sh \
    && ./scripts/build_web_vault.sh \
    && mv "${VAULT_FOLDER}/apps/web/build" ./web-vault \
    && sed -i "s/Promise.resolve(\"[0-9]\+\(\.[0-9]\+\)*\")/Promise.resolve(\"$(cat /vaultwarden/VAULTWARDEN_CUSTOM_VERSION)\")/g" ./web-vault/app/main.*.js

FROM rust:${RUST_VERSION}-alpine AS build_vaultwarden

WORKDIR /vaultwarden

COPY --from=get_info /tmp/BUILDTMP/VAULTWARDEN /vaultwarden

RUN \
    apk add --no-cache build-base openssl-dev openssl-libs-static \
    && export VW_VERSION=$(cat "/vaultwarden/VAULTWARDEN_CUSTOM_VERSION") \
    && cargo build --features sqlite --release

FROM scratch AS rebased_vaultwarden

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_vaultwarden /vaultwarden/target/release/vaultwarden /vaultwarden

COPY --from=build_vaultwarden_web /vaultwarden/web-vault /web-vault

FROM scratch

ENV \
    DATA_FOLDER="/etc/vaultwarden/data" \
    EXPERIMENTAL_CLIENT_FEATURE_FLAGS="autofill-overlay,autofill-v2,browser-fileless-import,extension-refresh,fido2-vault-credentials,inline-menu-positioning-improvements,ssh-agent,ssh-key-vault-item" \
    ROCKET_ADDRESS="0.0.0.0" ROCKET_PORT="8000" \
    WEB_VAULT_ENABLED="true" WEB_VAULT_FOLDER="/web-vault"

COPY --from=rebased_vaultwarden / /

EXPOSE 8000/tcp

ENTRYPOINT ["/vaultwarden"]
