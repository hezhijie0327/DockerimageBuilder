# Current Version: 1.0.7

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.clash" > "${WORKDIR}/clash.json" && cat "${WORKDIR}/clash.json" | jq -Sr ".version" && cat "${WORKDIR}/clash.json" | jq -Sr ".source" > "${WORKDIR}/clash.source.autobuild" && cat "${WORKDIR}/clash.json" | jq -Sr ".source_branch" > "${WORKDIR}/clash.source_branch.autobuild" && cat "${WORKDIR}/clash.json" | jq -Sr ".patch" > "${WORKDIR}/clash.patch.autobuild" && cat "${WORKDIR}/clash.json" | jq -Sr ".patch_branch" > "${WORKDIR}/clash.patch_branch.autobuild" && cat "${WORKDIR}/clash.json" | jq -Sr ".version" > "${WORKDIR}/clash.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_CLASH

WORKDIR /tmp

COPY --from=GET_INFO /tmp/clash.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && case "$(uname -m)" in ('x86_64'|'x86-64'|'x64'|'amd64') CPU_ARCH="amd64";; ('aarch64'|'arm64') CPU_ARCH="arm64";; (*) exit 1;; esac && git clone -b $(cat "${WORKDIR}/clash.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/clash.source.autobuild") "${WORKDIR}/BUILDTMP/CLASH" && git clone -b $(cat "${WORKDIR}/clash.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/clash.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export CLASH_SHA=$(cd "${WORKDIR}/BUILDTMP/CLASH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export CLASH_VERSION=$(cat "${WORKDIR}/clash.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export CLASH_CUSTOM_VERSION="${CLASH_VERSION}-ZHIJIE-${CLASH_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/CLASH" && go mod tidy && go get -u && go mod download && go mod vendor && make linux-${CPU_ARCH} VERSION="${CLASH_CUSTOM_VERSION}" && cp -rf "${WORKDIR}/BUILDTMP/CLASH/bin/clash-linux-${CPU_ARCH}" "${WORKDIR}/BUILDKIT/clash"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_CLASH /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/clash"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 53/tcp 53/udp 7890/tcp 7890/udp 7891/tcp 7891/udp 7892/tcp 7892/udp 7893/tcp 7893/udp 9090/tcp

ENTRYPOINT ["/clash"]
