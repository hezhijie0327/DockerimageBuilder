# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.rclone" > "${WORKDIR}/rclone.json" && cat "${WORKDIR}/rclone.json" | jq -Sr ".version" && cat "${WORKDIR}/rclone.json" | jq -Sr ".source" > "${WORKDIR}/rclone.source.autobuild" && cat "${WORKDIR}/rclone.json" | jq -Sr ".source_branch" > "${WORKDIR}/rclone.source_branch.autobuild" && cat "${WORKDIR}/rclone.json" | jq -Sr ".patch" > "${WORKDIR}/rclone.patch.autobuild" && cat "${WORKDIR}/rclone.json" | jq -Sr ".patch_branch" > "${WORKDIR}/rclone.patch_branch.autobuild" && cat "${WORKDIR}/rclone.json" | jq -Sr ".version" > "${WORKDIR}/rclone.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_RCLONE

WORKDIR /tmp

COPY --from=GET_INFO /tmp/rclone.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/rclone.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone.source.autobuild") "${WORKDIR}/BUILDTMP/RCLONE" && git clone -b $(cat "${WORKDIR}/rclone.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rclone.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export RCLONE_SHA=$(cd "${WORKDIR}/BUILDTMP/RCLONE" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export RCLONE_VERSION=$(cat "${WORKDIR}/rclone.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export RCLONE_CUSTOM_VERSION="v${RCLONE_VERSION}-ZHIJIE-${RCLONE_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/RCLONE" && export CGO_ENABLED=0 && go build -trimpath -ldflags "-s -X github.com/rclone/rclone/fs.Version=${RCLONE_CUSTOM_VERSION}" -tags cmount && cp -rf "${WORKDIR}/BUILDTMP/RCLONE/rclone" "${WORKDIR}/BUILDKIT/rclone"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_RCLONE /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/rclone"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/rclone"]
