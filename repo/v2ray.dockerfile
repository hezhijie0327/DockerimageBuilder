# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.v2ray" > "${WORKDIR}/v2ray.json" && cat "${WORKDIR}/v2ray.json" | jq -Sr ".version" && cat "${WORKDIR}/v2ray.json" | jq -Sr ".source" > "${WORKDIR}/v2ray.source.autobuild" && cat "${WORKDIR}/v2ray.json" | jq -Sr ".source_branch" > "${WORKDIR}/v2ray.source_branch.autobuild" && cat "${WORKDIR}/v2ray.json" | jq -Sr ".patch" > "${WORKDIR}/v2ray.patch.autobuild" && cat "${WORKDIR}/v2ray.json" | jq -Sr ".patch_branch" > "${WORKDIR}/v2ray.patch_branch.autobuild" && cat "${WORKDIR}/v2ray.json" | jq -Sr ".version" > "${WORKDIR}/v2ray.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_V2RAY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/v2ray.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/v2ray.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/v2ray.source.autobuild") "${WORKDIR}/BUILDTMP/V2RAY" && git clone -b $(cat "${WORKDIR}/v2ray.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/v2ray.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export V2RAY_SHA=$(cd "${WORKDIR}/BUILDTMP/V2RAY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export V2RAY_VERSION=$(cat "${WORKDIR}/v2ray.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export V2RAY_CUSTOM_VERSION="${V2RAY_VERSION}-ZHIJIE-${V2RAY_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/V2RAY" && go mod tidy && go get -u && go mod download && go mod vendor && export CGO_ENABLED=0 && go build -o v2ray -trimpath -ldflags "-X github.com/v2fly/v2ray-core/v5.version=${V2RAY_CUSTOM_VERSION} -s -w -buildid=" ./main && cp -rf "${WORKDIR}/BUILDTMP/V2RAY/v2ray" "${WORKDIR}/BUILDKIT/v2ray"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_V2RAY /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/v2ray"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/v2ray"]
