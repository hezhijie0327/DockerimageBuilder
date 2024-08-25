# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.authelia" > "${WORKDIR}/authelia.json" && cat "${WORKDIR}/authelia.json" | jq -Sr ".version" && cat "${WORKDIR}/authelia.json" | jq -Sr ".source" > "${WORKDIR}/authelia.source.autobuild" && cat "${WORKDIR}/authelia.json" | jq -Sr ".source_branch" > "${WORKDIR}/authelia.source_branch.autobuild" && cat "${WORKDIR}/authelia.json" | jq -Sr ".patch" > "${WORKDIR}/authelia.patch.autobuild" && cat "${WORKDIR}/authelia.json" | jq -Sr ".patch_branch" > "${WORKDIR}/authelia.patch_branch.autobuild" && cat "${WORKDIR}/authelia.json" | jq -Sr ".version" > "${WORKDIR}/authelia.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM hezhijie0327/base:ubuntu AS BUILD_AUTHELIA

WORKDIR /tmp

COPY --from=GET_INFO /tmp/authelia.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && npm install -g pnpm && git clone -b $(cat "${WORKDIR}/authelia.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/authelia.source.autobuild") "${WORKDIR}/BUILDTMP/AUTHELIA" && git clone -b $(cat "${WORKDIR}/authelia.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/authelia.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export AUTHELIA_SHA=$(cd "${WORKDIR}/BUILDTMP/AUTHELIA" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AUTHELIA_VERSION=$(cat "${WORKDIR}/authelia.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export AUTHELIA_CUSTOM_VERSION="${AUTHELIA_VERSION}-ZHIJIE-${AUTHELIA_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/AUTHELIA/web" && pnpm install && pnpm build && cp -rf "${WORKDIR}/BUILDTMP/AUTHELIA/api" "${WORKDIR}/BUILDTMP/AUTHELIA/internal/server/public_html/api" && cd "${WORKDIR}/BUILDTMP/AUTHELIA/cmd/authelia" && go mod tidy && go get -u && go mod download && go mod vendor && cd "${WORKDIR}/BUILDTMP/AUTHELIA" && sed -i "s/BuildTag = \"unknown\"/BuildTag = \"v${AUTHELIA_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/AUTHELIA/internal/utils/version.go" && CGO_ENABLED=1 CGO_CPPFLAGS="-D_FORTIFY_SOURCE=2 -fstack-protector-strong" CGO_LDFLAGS="-Wl,-z,relro,-z,now" go build -ldflags "-linkmode=external -s -w -extldflags -static" -trimpath -buildmode=pie -o authelia ./cmd/authelia && cp -rf "${WORKDIR}/BUILDTMP/AUTHELIA/authelia" "${WORKDIR}/BUILDKIT/authelia"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_AUTHELIA /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/authelia"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 9091/tcp

ENTRYPOINT ["/authelia"]
