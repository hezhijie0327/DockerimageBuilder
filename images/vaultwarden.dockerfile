ARG NODEJS_VERSION="22"
ARG RUST_VERSION="1"

ARG VAULTWARDEN_VERSION=""
ARG VAULTWARDEN_WEB_VERSION=""
ARG PATCH_SHA="0000"

FROM alpine:latest AS get_info

ARG VAULTWARDEN_VERSION
ARG VAULTWARDEN_WEB_VERSION
ARG PATCH_SHA

WORKDIR /tmp

RUN \
    apk add --no-cache curl git jq

RUN \
    export WORKDIR=$(pwd) \
    && export VAULTWARDEN_VERSION=${VAULTWARDEN_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/vaultwarden/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/"))] | last // "" | sub("^refs/tags/"; "")' \
    )} \
    && export VAULTWARDEN_WEB_VERSION=${VAULTWARDEN_WEB_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/bw_web_builds/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/v"))] | last // "" | sub("^refs/tags/v"; "")' \
    )} \
    && [ -n "${VAULTWARDEN_VERSION}" ] && [ -n "${VAULTWARDEN_WEB_VERSION}" ] \
    && echo "VAULTWARDEN_VERSION=${VAULTWARDEN_VERSION}" \
    && echo "VAULTWARDEN_WEB_VERSION=${VAULTWARDEN_WEB_VERSION}" \
    && git clone -b "main" --depth=1 "https://github.com/dani-garcia/vaultwarden.git" "${WORKDIR}/BUILDTMP/VAULTWARDEN" \
    && git clone -b "master" --depth=1 "https://github.com/dani-garcia/bw_web_builds.git" "${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB" \
    && export VAULTWARDEN_SHA=$(cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_CUSTOM_VERSION="${VAULTWARDEN_VERSION}-ZHIJIE-${VAULTWARDEN_SHA}${PATCH_SHA}" \
    && echo "${VAULTWARDEN_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/VAULTWARDEN/VAULTWARDEN_CUSTOM_VERSION" \
    && echo "${VAULTWARDEN_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/VAULTWARDEN_WEB/VAULTWARDEN_CUSTOM_VERSION" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/ca-certificates.crt"

FROM node:${NODEJS_VERSION}-slim AS build_vaultwarden_web

WORKDIR /vaultwarden

ENV \
    CHECKOUT_TAGS="false" \
    VAULT_FOLDER="bw_clients"

COPY --from=get_info /tmp/BUILDTMP/VAULTWARDEN_WEB /vaultwarden

RUN \
    apt update \
    && apt install -qy \
          build-essential \
          gcc \
          git \
          make \
          python3 \
    && export VAULT_VERSION=$(cat ./Dockerfile | grep "ARG VAULT_VERSION" | cut -d '=' -f 2) \
    && ./scripts/checkout_web_vault.sh \
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
    DATA_FOLDER="/data" \
    EXPERIMENTAL_CLIENT_FEATURE_FLAGS="autofill-overlay,autofill-v2,browser-fileless-import,extension-refresh,fido2-vault-credentials,inline-menu-positioning-improvements,ssh-agent,ssh-key-vault-item" \
    ROCKET_ADDRESS="0.0.0.0" ROCKET_PORT="8000" \
    WEB_VAULT_ENABLED="true" WEB_VAULT_FOLDER="/web-vault"

COPY --from=rebased_vaultwarden / /

EXPOSE 8000/tcp

ENTRYPOINT ["/vaultwarden"]
