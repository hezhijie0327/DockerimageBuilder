# Current Version: 1.1.4

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.xray" > "${WORKDIR}/xray.json" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".source" > "${WORKDIR}/xray.source.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".source_branch" > "${WORKDIR}/xray.source_branch.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".patch" > "${WORKDIR}/xray.patch.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".patch_branch" > "${WORKDIR}/xray.patch_branch.autobuild" \
    && cat "${WORKDIR}/xray.json" | jq -Sr ".version" > "${WORKDIR}/xray.version.autobuild"

FROM hezhijie0327/module:golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_XRAY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/xray.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" \
    && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && git clone -b $(cat "${WORKDIR}/xray.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/xray.source.autobuild") "${WORKDIR}/BUILDTMP/XRAY" \
    && git clone -b $(cat "${WORKDIR}/xray.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/xray.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export XRAY_SHA=$(cd "${WORKDIR}/BUILDTMP/XRAY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export XRAY_VERSION=$(cat "${WORKDIR}/xray.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export XRAY_CUSTOM_VERSION="${XRAY_VERSION}-ZHIJIE-${XRAY_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/XRAY" \
    && sed -i "s/Version_x, Version_y, Version_z/\"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 1)\", \"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 2)\", \"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 3)\"/g" "${WORKDIR}/BUILDTMP/XRAY/core/core.go" \
    && export CGO_ENABLED=0 \
    && go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main \
    && cp -rf "${WORKDIR}/BUILDTMP/XRAY/xray" "${WORKDIR}/BUILDKIT/xray"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_XRAY /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/xray"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/xray"]
