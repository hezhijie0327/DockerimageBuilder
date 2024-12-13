# Current Version: 1.1.6

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.vaultwarden" > "${WORKDIR}/vaultwarden.json" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".source" > "${WORKDIR}/vaultwarden.source.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".source_branch" > "${WORKDIR}/vaultwarden.source_branch.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".patch" > "${WORKDIR}/vaultwarden.patch.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".patch_branch" > "${WORKDIR}/vaultwarden.patch_branch.autobuild" \
    && cat "${WORKDIR}/vaultwarden.json" | jq -Sr ".version" > "${WORKDIR}/vaultwarden.version.autobuild"

FROM hezhijie0327/module:rust AS BUILD_RUST

FROM hezhijie0327/base:alpine as BUILD_VAULTWARDEN

COPY --from=GET_INFO /tmp/vaultwarden.*.autobuild /tmp/

COPY --from=BUILD_RUST / /tmp/BUILDLIB/

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" \
    && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.source.autobuild") "${WORKDIR}/BUILDTMP/VAULTWARDEN" \
    && git clone -b $(cat "${WORKDIR}/vaultwarden.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vaultwarden.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export VAULTWARDEN_SHA=$(cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_VERSION=$(cat "${WORKDIR}/vaultwarden.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VAULTWARDEN_CUSTOM_VERSION="${VAULTWARDEN_VERSION}-ZHIJIE-${VAULTWARDEN_SHA}${PATCH_SHA}" \
    && bash "${WORKDIR}/BUILDLIB/install.sh" \
    && cd "${WORKDIR}/BUILDTMP/VAULTWARDEN" \
    && export VW_VERSION="${VAULTWARDEN_CUSTOM_VERSION}" \
    && cargo build --features sqlite --release \
    && cp -rf "${WORKDIR}/BUILDTMP/VAULTWARDEN/target/release/vaultwarden" "${WORKDIR}/BUILDKIT/vaultwarden" \
    && echo "${VAULTWARDEN_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/vaultwarden.version"

FROM hezhijie0327/base:alpine AS BUILD_VAULTWARDEN_WEB

COPY --from=BUILD_VAULTWARDEN /tmp/BUILDTMP/vaultwarden.version /tmp/vaultwarden.version

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDTMP/VAULTWARDEN-WEB" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && export latest_version=$(curl -s "https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest" | jq -r .tag_name) \
    && cd "${WORKDIR}/BUILDTMP/VAULTWARDEN-WEB" \
    && curl -Ls -o - "https://github.com/dani-garcia/bw_web_builds/releases/download/${latest_version}/bw_web_${latest_version}.tar.gz" | tar zxvf - --strip-components=1 \
    && mv "${WORKDIR}/BUILDTMP/VAULTWARDEN-WEB" "${WORKDIR}/BUILDKIT/web-vault" \
    && sed -i "s/Promise.resolve(\"[0-9]\+\(\.[0-9]\+\)*\")/Promise.resolve(\"$(cat ${WORKDIR}/vaultwarden.version)\")/g" ${WORKDIR}/BUILDKIT/web-vault/app/main.*.js

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_VAULTWARDEN /tmp/BUILDKIT /tmp/BUILDKIT

COPY --from=BUILD_VAULTWARDEN_WEB /tmp/BUILDKIT/web-vault /tmp/BUILDKIT/web-vault

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vaultwarden"

FROM scratch

ENV \
    DATA_FOLDER="/etc/vaultwarden/data" \
    ROCKET_ADDRESS="0.0.0.0" ROCKET_PORT="8000" \
    WEB_VAULT_ENABLED="true" WEB_VAULT_FOLDER="/web-vault"

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 8000/tcp

ENTRYPOINT ["/vaultwarden"]
