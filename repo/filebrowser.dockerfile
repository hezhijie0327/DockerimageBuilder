# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.filebrowser" > "${WORKDIR}/filebrowser.json" && cat "${WORKDIR}/filebrowser.json" | jq -Sr ".version" && cat "${WORKDIR}/filebrowser.json" | jq -Sr ".source" > "${WORKDIR}/filebrowser.source.autobuild" && cat "${WORKDIR}/filebrowser.json" | jq -Sr ".source_branch" > "${WORKDIR}/filebrowser.source_branch.autobuild" && cat "${WORKDIR}/filebrowser.json" | jq -Sr ".patch" > "${WORKDIR}/filebrowser.patch.autobuild" && cat "${WORKDIR}/filebrowser.json" | jq -Sr ".patch_branch" > "${WORKDIR}/filebrowser.patch_branch.autobuild" && cat "${WORKDIR}/filebrowser.json" | jq -Sr ".version" > "${WORKDIR}/filebrowser.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM hezhijie0327/base:ubuntu AS BUILD_FILEBROWSER

WORKDIR /tmp

COPY --from=GET_INFO /tmp/filebrowser.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/filebrowser.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/filebrowser.source.autobuild") "${WORKDIR}/BUILDTMP/FILEBROWSER" && git clone -b $(cat "${WORKDIR}/filebrowser.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/filebrowser.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export FILEBROWSER_SHA=$(cd "${WORKDIR}/BUILDTMP/FILEBROWSER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export FILEBROWSER_VERSION=$(cat "${WORKDIR}/filebrowser.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export FILEBROWSER_CUSTOM_VERSION="${FILEBROWSER_VERSION}-ZHIJIE-${FILEBROWSER_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/FILEBROWSER/frontend" && npm ci && npm run build && cd "${WORKDIR}/BUILDTMP/FILEBROWSER" && export CGO_ENABLED=0 && go build -ldflags "-s -w -X github.com/filebrowser/filebrowser/v2/version.Version=${FILEBROWSER_CUSTOM_VERSION} -X github.com/filebrowser/filebrowser/v2/version.CommitSHA=$(go version | awk '{print $3}')" -o "${WORKDIR}/BUILDKIT"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_filebrowser /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/filebrowser"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 8080/tcp

ENTRYPOINT ["/filebrowser"]
