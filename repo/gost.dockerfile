# Current Version: 1.1.2

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.gost" > "${WORKDIR}/gost.json" && cat "${WORKDIR}/gost.json" | jq -Sr ".version" && cat "${WORKDIR}/gost.json" | jq -Sr ".source" > "${WORKDIR}/gost.source.autobuild" && cat "${WORKDIR}/gost.json" | jq -Sr ".source_branch" > "${WORKDIR}/gost.source_branch.autobuild" && cat "${WORKDIR}/gost.json" | jq -Sr ".patch" > "${WORKDIR}/gost.patch.autobuild" && cat "${WORKDIR}/gost.json" | jq -Sr ".patch_branch" > "${WORKDIR}/gost.patch_branch.autobuild" && cat "${WORKDIR}/gost.json" | jq -Sr ".version" > "${WORKDIR}/gost.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_GOST

WORKDIR /tmp

COPY --from=GET_INFO /tmp/gost.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/gost.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/gost.source.autobuild") "${WORKDIR}/BUILDTMP/GOST" && git clone -b $(cat "${WORKDIR}/gost.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/gost.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export GOST_SHA=$(cd "${WORKDIR}/BUILDTMP/GOST" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export GOST_VERSION=$(cat "${WORKDIR}/gost.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export GOST_CUSTOM_VERSION="${GOST_VERSION}-ZHIJIE-${GOST_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/GOST/cmd/gost" && go mod tidy && go get -u && go mod download && go mod vendor && go mod edit -require=golang.zx2c4.com/wireguard@v0.0.0-20220703234212-c31a7b1ab478 && go mod edit -require=github.com/quic-go/quic-go@v0.42.0 && go mod edit -require=github.com/quic-go/webtransport-go@v0.7.0 && go mod tidy && go mod vendor && sed -i "s/version = \".*\"/version = \"${GOST_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/GOST/cmd/gost/version.go" && export CGO_ENABLED="0" && go build -v && cp -rf "${WORKDIR}/BUILDTMP/GOST/cmd/gost/gost" "${WORKDIR}/BUILDKIT/gost"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_GOST /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/gost"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 443/udp 80/tcp

ENTRYPOINT ["/gost"]
