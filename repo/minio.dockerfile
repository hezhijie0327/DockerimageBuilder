# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.minio" > "${WORKDIR}/minio.json" && cat "${WORKDIR}/minio.json" | jq -Sr ".version" && cat "${WORKDIR}/minio.json" | jq -Sr ".source" > "${WORKDIR}/minio.source.autobuild" && cat "${WORKDIR}/minio.json" | jq -Sr ".source_branch" > "${WORKDIR}/minio.source_branch.autobuild" && cat "${WORKDIR}/minio.json" | jq -Sr ".patch" > "${WORKDIR}/minio.patch.autobuild" && cat "${WORKDIR}/minio.json" | jq -Sr ".patch_branch" > "${WORKDIR}/minio.patch_branch.autobuild" && cat "${WORKDIR}/minio.json" | jq -Sr ".version" > "${WORKDIR}/minio.version.autobuild"

FROM hezhijie0327/module:golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_MINIO

WORKDIR /tmp

COPY --from=GET_INFO /tmp/minio.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/minio.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/minio.source.autobuild") "${WORKDIR}/BUILDTMP/MINIO" && git clone -b $(cat "${WORKDIR}/minio.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/minio.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export MINIO_SHA=$(cd "${WORKDIR}/BUILDTMP/MINIO" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MINIO_VERSION=$(cat "${WORKDIR}/minio.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MINIO_CUSTOM_VERSION="${MINIO_VERSION}-ZHIJIE-${MINIO_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/MINIO" && export CGO_ENABLED=0 && go build -o minio -trimpath -ldflags "$(go run buildscripts/gen-ldflags.go) -X github.com/minio/minio/cmd.ReleaseTag=DEVELOPMENT.${MINIO_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/BUILDTMP/MINIO/minio" "${WORKDIR}/BUILDKIT/minio"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_MINIO /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/minio"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/minio"]
